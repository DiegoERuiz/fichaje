# Fichaje Deploy - PowerShell Script
# Usage: .\deploy-fichaje.ps1

$VpsIp = "87.106.125.173"
$VpsUser = "root"
$VpsHost = "$VpsUser@$VpsIp"
$RepoUrl = "https://github.com/DiegoERuiz/fichaje.git"
$AppDir = "/opt/fichaje"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FICHAJE DEPLOYMENT - PowerShell" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Read secrets from .env
Write-Host "[*] Reading secrets from deploy/prod/.env..." -ForegroundColor Yellow

$envPath = Join-Path -Path (Get-Location) -ChildPath "deploy" | Join-Path -ChildPath "prod" | Join-Path -ChildPath ".env"

if (-not (Test-Path $envPath)) {
    Write-Host "[ERROR] File $envPath not found" -ForegroundColor Red
    Write-Host "Current directory: $(Get-Location)" -ForegroundColor Gray
    Write-Host "Searching for .env files..." -ForegroundColor Gray
    Get-ChildItem -Recurse -Filter ".env*" | ForEach-Object { Write-Host "  Found: $($_.FullName)" -ForegroundColor Gray }
    exit 1
}

$envContent = Get-Content $envPath -Raw

# Extract values - more reliable method
$jwtSecret = ($envContent | Select-String 'JWT_SECRET=' | ForEach-Object { $_.Line.Split('=', 2)[1] }).Trim()
$mysqlPassword = ($envContent | Select-String 'MYSQL_PASSWORD=' | ForEach-Object { $_.Line.Split('=', 2)[1] }).Trim()
$mysqlRootPassword = ($envContent | Select-String 'MYSQL_ROOT_PASSWORD=' | ForEach-Object { $_.Line.Split('=', 2)[1] }).Trim()
$sslKeystorePassword = ($envContent | Select-String 'SSL_KEYSTORE_PASSWORD=' | ForEach-Object { $_.Line.Split('=', 2)[1] }).Trim()

if ([string]::IsNullOrEmpty($jwtSecret)) {
    Write-Host "[ERROR] Cannot read JWT_SECRET from .env" -ForegroundColor Red
    exit 1
}

Write-Host "[+] Secrets loaded successfully" -ForegroundColor Green
Write-Host "    JWT_SECRET: $($jwtSecret.Substring(0, 20))..." -ForegroundColor Gray
Write-Host "    Other secrets: ****" -ForegroundColor Gray
Write-Host ""

# Test SSH connection
Write-Host "[*] Testing SSH connection to $VpsHost..." -ForegroundColor Yellow
$sshTest = ssh -o ConnectTimeout=5 $VpsHost "echo OK" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Cannot connect to $VpsHost" -ForegroundColor Red
    exit 1
}

Write-Host "[+] SSH connection successful" -ForegroundColor Green
Write-Host ""

# Create deployment script
Write-Host "[*] Creating deployment commands..." -ForegroundColor Yellow

$deployCommands = @"
#!/bin/bash
set -e

echo '[1/15] Creating directories...'
mkdir -p $AppDir
cd $AppDir

echo '[2/15] Updating system...'
apt-get update -qq
apt-get upgrade -y -qq

echo '[3/15] Installing Docker...'
curl -fsSL https://get.docker.com -o get-docker.sh 2>/dev/null
sh get-docker.sh > /dev/null 2>&1
rm get-docker.sh

echo '[4/15] Installing Docker Compose...'
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-`$(uname -s)-`$(uname -m)" -o /usr/local/bin/docker-compose 2>/dev/null
chmod +x /usr/local/bin/docker-compose

echo '[5/15] Starting Docker...'
systemctl start docker
systemctl enable docker > /dev/null 2>&1

echo '[6/15] Cloning repository...'
cd /opt
rm -rf fichaje 2>/dev/null || true
git clone $RepoUrl fichaje
cd fichaje

echo '[7/15] Installing Java 11...'
apt-get install -y -qq openjdk-11-jdk maven

echo '[8/15] Building backend (may take 10 minutes)...'
cd $AppDir/apps/fichaje-be
mvn clean package -DskipTests -q

echo '[9/15] Installing Node.js...'
curl -fsSL https://deb.nodesource.com/setup_18.x | bash - > /dev/null 2>&1
apt-get install -y -qq nodejs

echo '[10/15] Building frontend...'
cd $AppDir/apps/fichaje-fe
npm install > /dev/null 2>&1
npm run build -- --prod > /dev/null 2>&1

echo '[11/15] Installing Certbot...'
apt-get install -y -qq certbot python3-certbot-nginx

echo '[12/15] Generating SSL certificate...'
certbot certonly --standalone \
    -d fichajes.biedma.com \
    --non-interactive \
    --agree-tos \
    -m admin@fichajes.biedma.com 2>/dev/null || echo 'Certificate may exist'

echo '[13/15] Generating keystore...'
cd $AppDir
openssl pkcs12 -export \
    -in /etc/letsencrypt/live/fichajes.biedma.com/fullchain.pem \
    -inkey /etc/letsencrypt/live/fichajes.biedma.com/privkey.pem \
    -out $AppDir/fichajes-keystore.p12 \
    -name fichaje \
    -passout pass:$sslKeystorePassword 2>/dev/null || true

echo '[14/15] Starting Docker Compose...'
docker-compose -f docker-compose-prod.yml up -d

echo '[15/15] Waiting for services to start...'
sleep 30

echo ''
echo '[+] Deployment steps completed!'
docker-compose -f docker-compose-prod.yml ps
"@

Write-Host "[+] Commands prepared" -ForegroundColor Green
Write-Host ""

# Execute deployment
Write-Host "[*] Executing deployment on VPS..." -ForegroundColor Yellow
Write-Host "    This will take 20-30 minutes (compiling backend and frontend)" -ForegroundColor Gray
Write-Host ""

$deployCommands | ssh $VpsHost "bash -s"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Deployment failed" -ForegroundColor Red
    exit 1
}

# Create .env file on remote
Write-Host ""
Write-Host "[*] Configuring environment on VPS..." -ForegroundColor Yellow

$envFile = @"
APP_PORT=8080
APP_SSL_PORT=8443
DB_PORT=3306
ENABLE_SSL=true
DOMAIN=fichajes.biedma.com
LETSENCRYPT_EMAIL=admin@fichajes.biedma.com
MYSQL_ROOT_PASSWORD=$mysqlRootPassword
MYSQL_DATABASE=db_fichajespi_prod
MYSQL_USER=fichajes_prod
MYSQL_PASSWORD=$mysqlPassword
MYSQL_INITDB_SKIP_TZINFO=yes
TZ=Europe/Madrid
IP=fichajes.biedma.com
CLIENT_URL=https://fichajes.biedma.com
APP_DOMAIN=fichajes.biedma.com
APP_URL=https://fichajes.biedma.com
JWT_SECRET=$jwtSecret
JWT_EXPIRATION=36000000
JWT_REFRESH_EXPIRATION=604800000
SSL_KEYSTORE_PASSWORD=$sslKeystorePassword
SSL_KEYSTORE_ALIAS=fichaje
KEYSTORE_PATH=/opt/fichaje/fichajes-keystore.p12
REDIS_HOST=redis
REDIS_PORT=6379
PROMETHEUS_PORT=9090
GRAFANA_PASSWORD=admin123
GRAFANA_ADMIN_USER=admin
SPRING_PROFILES_ACTIVE=prod
SPRING_JPA_HIBERNATE_DDL_AUTO=validate
LOGGING_LEVEL_ROOT=WARN
LOGGING_LEVEL_ORG_SPRINGFRAMEWORK=WARN
"@

$envFile | ssh $VpsHost "cat > $AppDir/.env"

Write-Host "[+] Environment file created" -ForegroundColor Green
Write-Host ""

# Final verification
Write-Host "[*] Final verification..." -ForegroundColor Yellow
ssh $VpsHost "cd $AppDir && docker-compose -f docker-compose-prod.yml ps"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "DEPLOYMENT COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Access URLs:" -ForegroundColor Cyan
Write-Host "  Application:  https://fichajes.biedma.com" -ForegroundColor White
Write-Host "  Grafana:      http://87.106.125.173:3000 (admin/admin123)" -ForegroundColor White
Write-Host "  Prometheus:   http://87.106.125.173:9090" -ForegroundColor White
Write-Host "  API Health:   https://fichajes.biedma.com/actuator/health" -ForegroundColor White
Write-Host ""
Write-Host "Useful commands:" -ForegroundColor Cyan
Write-Host "  View logs:    ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose logs -f backend'" -ForegroundColor Gray
Write-Host "  Check status: ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose ps'" -ForegroundColor Gray
Write-Host "  Restart all:  ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose restart'" -ForegroundColor Gray
Write-Host ""
