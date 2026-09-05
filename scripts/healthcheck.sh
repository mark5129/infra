#!/bin/bash
# Logs container health and disk space. Run via cron every 5 minutes.
#
# Requires two environment variables set by the caller (e.g. exported in the
# crontab line, or a wrapper script sourced before this one) — no
# project-specific default, so one script serves every project on the box:
#   PROJECT_NAME  – used only for the log filename, e.g. "travelplanner"
#   COMPOSE_DIR   – absolute path to the project's docker-compose directory

: "${PROJECT_NAME:?PROJECT_NAME must be set (used for the log filename)}"
: "${COMPOSE_DIR:?COMPOSE_DIR must be set (path to the project's docker-compose directory)}"

LOG="/var/log/${PROJECT_NAME}-health.log"
DISK_WARN=80   # alert when disk usage exceeds this %

echo "--- $(date -u +"%Y-%m-%dT%H:%M:%SZ") ---" >> "$LOG"

# Container health
docker ps --format '{{.Names}} {{.Status}}' 2>/dev/null | while read -r name status; do
    if echo "$status" | grep -q "unhealthy"; then
        echo "ALERT: $name is UNHEALTHY ($status)" >> "$LOG"
    elif echo "$status" | grep -q "Restarting"; then
        echo "ALERT: $name is RESTARTING ($status)" >> "$LOG"
    fi
done

# Disk usage
df -h / | awk 'NR==2 {
    usage = $5
    gsub(/%/, "", usage)
    if (usage+0 >= '"$DISK_WARN"') {
        print "ALERT: Disk usage at " $5 " (used: " $3 " / " $2 ")"
    }
}' >> "$LOG"

# Trim log to last 1000 lines
tail -n 1000 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
