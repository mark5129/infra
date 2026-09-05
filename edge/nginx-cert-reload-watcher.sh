#!/bin/sh
# nginx loads TLS certs into memory at startup/reload and never re-reads them
# per-connection, so a cert renewed on disk by the certbot container is
# silently ignored until something reloads nginx. Poll the live cert's mtime
# and reload whenever certbot writes a new one.
#
# Runs as a background loop started from docker-entrypoint.d, which does not
# block nginx from starting.
set -eu

CERT_FILE="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
CHECK_INTERVAL=900 # 15 minutes

(
    last_mtime=""
    while true; do
        sleep "$CHECK_INTERVAL"
        if [ -f "$CERT_FILE" ]; then
            mtime=$(stat -c %Y "$CERT_FILE" 2>/dev/null || echo "")
            if [ -n "$last_mtime" ] && [ "$mtime" != "$last_mtime" ]; then
                echo "$(date -Iseconds) cert change detected for ${DOMAIN}, reloading nginx"
                nginx -s reload || echo "$(date -Iseconds) nginx reload failed"
            fi
            last_mtime="$mtime"
        fi
    done
) &
