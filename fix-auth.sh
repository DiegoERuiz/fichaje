#!/bin/bash
# Create .htpasswd file with htpasswd command
echo "Creating .htpasswd file..."

# Install apache2-utils if not present
apk add --no-cache apache2-utils 2>/dev/null || apt-get update && apt-get install -y apache2-utils 2>/dev/null || true

# Create htpasswd file with user biedma and password password123
htpasswd -bc /tmp/.htpasswd biedma password123

# Show contents
echo "=== .htpasswd contents ==="
cat /tmp/.htpasswd

# Copy to Caddy container
docker cp /tmp/.htpasswd fichaje_proxy:/tmp/.htpasswd

# Update Caddyfile to use htpasswd file instead of bcrypt
echo "Updating Caddyfile..."
cat > /tmp/Caddyfile.new <<'CADDY'
fichajes.biedma.com {
	tls it@biedma.com
	handle /api/* {
		uri strip_prefix /api
		reverse_proxy backend:8080 {
			lb_try_duration 30s
			lb_try_interval 1s
		}
	}
	handle /db/* {
		basicauth {
			realm "restricted"
			biedma password123
		}
		uri strip_prefix /db
		reverse_proxy phpmyadmin:80
	}
	handle {
		reverse_proxy frontend:80
	}
}
:80 {
	handle /api/* {
		uri strip_prefix /api
		reverse_proxy backend:8080 {
			lb_try_duration 30s
			lb_try_interval 1s
		}
	}
	handle /db/* {
		basicauth {
			realm "restricted"
			biedma password123
		}
		uri strip_prefix /db
		reverse_proxy phpmyadmin:80
	}
	handle {
		reverse_proxy frontend:80
	}
}
CADDY

cp /tmp/Caddyfile.new /opt/fichaje/deploy/prod/Caddyfile
docker restart fichaje_proxy
sleep 3

# Test
echo "Testing..."
curl -u biedma:password123 http://127.0.0.1/db/ -s -o /dev/null -w "Status: %{http_code}\n"
