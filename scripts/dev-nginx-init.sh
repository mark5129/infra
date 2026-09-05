#!/bin/sh
set -e
apk add --no-cache openssl > /dev/null 2>&1
printf '%s\n' "${DEV_NGINX_USER}:$(openssl passwd -apr1 "${DEV_NGINX_PASSWORD}")" > /etc/nginx/.htpasswd
exec nginx -g 'daemon off;'
