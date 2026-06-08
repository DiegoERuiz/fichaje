#!/bin/bash
# Generate .htpasswd file with credentials
# Username: biedma
# Password: SecureDbAccess#2024!Prod

# Install htpasswd if needed
apt-get update -qq && apt-get install -y -qq apache2-utils > /dev/null 2>&1

# Create .htpasswd file
htpasswd -bc /opt/fichaje/deploy/prod/.htpasswd biedma "SecureDbAccess#2024!Prod"

# Verify
echo "✅ .htpasswd created:"
cat /opt/fichaje/deploy/prod/.htpasswd
