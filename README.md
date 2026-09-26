# Monitoring (pi-alpha)

Infrastructure stack for the Raspberry Pi: the **reverse proxy** for every
app on the Pi, plus lightweight **monitoring** and a **traffic report**.

| Service | Role | RAM (approx.) |
|---|---|---|
| **Caddy** | Reverse proxy + automatic HTTPS for all sites (`caddy/sites/*.caddy`); writes the access log | ~45 MB |
| **Beszel hub** | Dashboard at https://monitor.wgcodings.com: history, alerts, own login | ~20-30 MB |
| **Beszel agent** | Collects this Pi's CPU, RAM, disk, temperature, network and per-container stats (from Docker directly) | ~10 MB |
| **GoAccess** | Every 5 min turns Caddy's access log into a visitor report at https://monitor.wgcodings.com/traffic (password) | ~few MB |

## How the sites fit together

```
internet ──► Caddy (this stack, 80/443)
              ├─ monitor.wgcodings.com          ─► beszel:8090                (this stack)
              ├─ monitor.wgcodings.com/traffic  ─► GoAccess report (static, password)
              ├─ trailcraft.wgcodings.com       ─► trailcraft-backend-1:8000  (~/TrailCraft, via `edge`)
              │                                  └► trailcraft-frontend-1:80
              └─ openbench.wgcodings.com        ─► openbench:8000             (~/OpenBench, via `edge`)
```

### Adding a new app

1. In the app's `docker-compose.yml`, put the web container on `edge`
   (`networks: [default, edge]` + `networks: { edge: { external: true } }`).
2. Add `caddy/sites/<app>.caddy`:
   ```
   myapp.wgcodings.com {
   	import access_log
   	reverse_proxy <container-name>:<port>
   }
   ```
3. Add the DNS record at Combell (CNAME to `monitor.wgcodings.com`).
4. Reload Caddy without downtime:
   `docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile`

### Adding another Pi / machine to the dashboard

Only the agent runs there; the hub on pi-alpha collects and stores
everything. See `agent/docker-compose.yml` (copy the `agent/` folder to
the other machine, add it in the hub, paste the key, `docker compose up -d`).

## Setup

1. **Traffic password hash** (on the Pi):
   ```bash
   docker run --rm caddy:2-alpine caddy hash-password --plaintext 'your-password'
   ```
2. **Configure:**
   ```bash
   cd ~/Monitoring
   cp .env.example .env
   nano .env      # paste the hash into TRAFFIC_PASS_HASH='...' (keep the single quotes)
   ```
3. **Start:**
   ```bash
   docker compose up -d --remove-orphans
   ```
4. **Create the Beszel admin account straight away**: open
   https://monitor.wgcodings.com. The first visitor gets to create it.
5. **Add this Pi in Beszel:** *Add system* →
   - Name: `pi-alpha`
   - Host / IP: `/beszel_socket/beszel.sock`

   Copy the **public key** from the dialog into `.env` as
   `BESZEL_AGENT_KEY=ssh-ed25519 AAAA...`, then:
   ```bash
   docker compose up -d beszel-agent
   ```
   Click *Add system*. It turns green within a minute.
6. **Traffic report:** https://monitor.wgcodings.com/traffic appears after
   the first visits have been logged and GoAccess has run (up to 5 min).

## Using it

- **Beszel dashboard:** one row per machine. Click it for graphs of CPU,
  RAM, disk, disk I/O, network and temperature, and per-container CPU,
  memory and network. Pick the time range (1 h to 30 days) top right.
- **Alerts:** bell icon per system (CPU, memory, disk, temperature,
  "system down"). Configure where they go under *Settings → Notifications*
  (Telegram, Discord, e-mail, ntfy, ...).
- **Traffic report:** hits and unique visitors per day, per site
  ("Virtual Hosts"), top pages, status codes (404s, 5xx), browsers and
  operating systems. OpenBench counts every worker poll, so it dominates.

## Troubleshooting

- **Beszel system stays red:** check `docker compose logs beszel-agent`;
  the key in `.env` must match the one shown in the hub exactly.
- **No per-container memory:** the memory cgroup must be enabled
  (`cgroup_enable=memory cgroup_memory=1` in `/boot/firmware/cmdline.txt`,
  already done on pi-alpha).
- **/traffic gives 404:** no report yet; check `docker compose logs goaccess`
  and that `logs/caddy/access.log` exists and is growing.
- **502 on a site:** Caddy can't reach the container. Check it's running
  and on `edge`: `docker network inspect edge --format '{{range .Containers}}{{.Name}} {{end}}'`.
