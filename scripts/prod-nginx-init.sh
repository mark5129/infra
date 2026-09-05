#!/bin/sh
# Generates a temporary self-signed cert if Let's Encrypt certs don't exist yet.
# Allows nginx to start before TLS bootstrap is complete.
# certbot will overwrite this with a real cert during the bootstrap step.
set -e
CERT_DIR="/etc/letsencrypt/live/${DOMAIN}"
if [ ! -f "${CERT_DIR}/fullchain.pem" ]; then
    echo "No cert found for ${DOMAIN} — generating temporary self-signed cert"
    apk add --no-cache openssl > /dev/null 2>&1
    mkdir -p "${CERT_DIR}"
    openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout "${CERT_DIR}/privkey.pem" \
        -out  "${CERT_DIR}/fullchain.pem" \
        -days 1 -subj "/CN=${DOMAIN}"
    echo "Self-signed cert created — run TLS bootstrap to replace with real cert"
fi
