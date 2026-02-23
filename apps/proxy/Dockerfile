FROM caddy:2-alpine

COPY Caddyfile.http /etc/caddy/Caddyfile.http
COPY Caddyfile.https /etc/caddy/Caddyfile.https
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
