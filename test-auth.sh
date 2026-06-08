#!/bin/bash
docker restart fichaje_proxy
sleep 3
echo "=== Testing with basic auth: biedma/test123 ==="
curl -u biedma:test123 http://127.0.0.1/db/ -s -o /dev/null -w "HTTP Status: %{http_code}\n"
