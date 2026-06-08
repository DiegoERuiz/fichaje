#!/bin/bash
# Test with a very simple password
PASSWORD="password123"
HASH=$(docker exec fichaje_proxy caddy hash-password -plaintext "$PASSWORD")
echo "Hash for '$PASSWORD': $HASH"

# Create backup
cp /opt/fichaje/deploy/prod/Caddyfile /opt/fichaje/deploy/prod/Caddyfile.bak

# Update Caddyfile
sed -i "s|biedma \$2a\$14\$[^}]*|biedma $HASH|g" /opt/fichaje/deploy/prod/Caddyfile

echo "Testing immediately after generation..."
docker restart fichaje_proxy
sleep 3
curl -u biedma:$PASSWORD http://127.0.0.1/db/ -s -o /dev/null -w "Status for '$PASSWORD': %{http_code}\n"
