#!/bin/bash
set -e

# Generate hash for test123
HASH=$(docker exec fichaje_proxy caddy hash-password -plaintext 'test123')
echo "Generated hash: $HASH"

# Update Caddyfile with the new hash
sed -i "s|biedma \$2a\$14\$[^}]*|biedma $HASH|g" /opt/fichaje/deploy/prod/Caddyfile

# Show the updated content
echo "Updated Caddyfile /db/* section:"
grep -A 5 "handle /db" /opt/fichaje/deploy/prod/Caddyfile | head -10

# Restart proxy
docker restart fichaje_proxy
sleep 3

# Test
echo "Testing authentication..."
curl -u biedma:test123 http://127.0.0.1/db/ -s -o /dev/null -w "Status: %{http_code}\n"
