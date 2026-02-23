#!/bin/sh
set -e

if [ "$ENABLE_SSL" = "true" ]; then
  echo "🔒 SSL habilitado — usando Caddyfile.https (dominio: ${DOMAIN})"
  cp /etc/caddy/Caddyfile.https /etc/caddy/Caddyfile
else
  echo "🌐 SSL deshabilitado — usando Caddyfile.http (puerto 80)"
  cp /etc/caddy/Caddyfile.http /etc/caddy/Caddyfile
fi

exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
