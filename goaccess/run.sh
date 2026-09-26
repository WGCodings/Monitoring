#!/bin/sh
# Rebuilds the traffic report from Caddy's access log every 5 minutes.
# --persist/--restore keep the statistics in /goaccess_db, so history
# survives log rotation and container restarts.
while true; do
    if [ -s /var/log/caddy/access.log ]; then
        goaccess /var/log/caddy/access.log \
            --log-format=CADDY \
            --persist --restore --db-path=/goaccess_db \
            --html-report-title="WGCodings - Traffic" \
            -o /report/index.html
    fi
    sleep 300
done
