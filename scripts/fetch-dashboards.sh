#!/usr/bin/env sh
# Downloads community dashboards from grafana.com into grafana/dashboards/,
# where Grafana picks them up automatically (within ~30s, no restart).
# Run from the repo root on the Pi:  sh scripts/fetch-dashboards.sh
set -eu
cd "$(dirname "$0")/../grafana/dashboards"

fetch() { # <grafana.com id> <file name>
    echo "Fetching dashboard $1 -> $2"
    curl -fsSL "https://grafana.com/api/dashboards/$1/revisions/latest/download" \
        | sed -e 's/\${DS_PROMETHEUS}/prometheus/g' > "$2"
}

fetch 1860 node-exporter-full.json   # Node Exporter Full: every Pi metric in detail
