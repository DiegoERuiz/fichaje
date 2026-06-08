# ═══════════════════════════════════════════════════════════════════════════
# FICHAJE DEPLOY - PowerShell Script for Windows
# ═══════════════════════════════════════════════════════════════════════════
# Usage: .\deploy-fichaje.ps1

param(
    [string]$VpsIp = "87.106.125.173",
    [string]$VpsUser = "root",
    [string]$RepoUrl = "https://github.com/DiegoERuiz/fichaje.git",
    [string]$AppDir = "/opt/fichaje"
)

$VpsHost = "$VpsUser@$VpsIp"
$ErrorActionPreference = "Stop"

# Color functions
function Write-Header {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host $args[0] -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
}

function Write-Success {
    Write-Host "✓ $($args[0])" -ForegroundColor Green
}

function Write-Warning {
    Write-Host "⚠ $($args[0])" -ForegroundColor Yellow
}

function Write-Error-Custom {
    Write-Host "✗ $($args[0])" -ForegroundColor Red
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 0: Read secrets from .env file
# ═══════════════════════════════════════════════════════════════════════════
Write-Header "🔐 READING SECRETS FROM .env"

if (-not (Test-Path "deploy/prod/.env")) {
    Write-Error-Custom "File deploy/prod/.env not found"
    exit 1
}

$envContent = Get-Content "deploy/prod/.env" -Raw
$env:JWT_SECRET = ($envContent | Select-String 'JWT_SECRET=(.*)' | ForEach-Object { $_.Matches[0].Groups[1].Value }).Trim()
$env:MYSQL_PASSWORD = ($envContent | Select-String 'MYSQL_PASSWORD=(.*)' | ForEach-Object { $_.Matches[0].Groups[1].Value }).Trim()
$env:MYSQL_ROOT_PASSWORD = ($envContent | Select-String 'MYSQL_ROOT_PASSWORD=(.*)' | ForEach-Object { $_.Matches[0].Groups[1].Value }).Trim()
$env:SSL_KEYSTORE_PASSWORD = ($envContent | Select-String 'SSL_KEYSTORE_PASSWORD=(.*)' | ForEach-Object { $_.Matches[0].Groups[1].Value }).Trim()

if ([string]::IsNullOrEmpty($env:JWT_SECRET)) {
    Write-Error-Custom "Cannot read JWT_SECRET from .env"
    exit 1
}

Write-Success "Secrets loaded from deploy/prod/.env"
Write-Host "JWT_SECRET: $($env:JWT_SECRET.Substring(0, 20))..."
Write-Host "MYSQL_ROOT_PASSWORD: ****"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 1: Test SSH connection
# ═══════════════════════════════════════════════════════════════════════════
Write-Header "🔍 TESTING SSH CONNECTION"

Write-Host "Connecting to $VpsHost..."
try {
    ssh -o ConnectTimeout=5 $VpsHost "echo OK" | Out-Null
    Write-Success "SSH connection successful"
} catch {
    Write-Error-Custom "Cannot connect to $VpsHost"
    exit 1
}

# ═══════════════════════════════════════════════════════════════════════════
# STEP 2: Create remote commands script
# ═══════════════════════════════════════════════════════════════════════════
Write-Header "📝 PREPARING DEPLOYMENT COMMANDS"

$remoteScript = @"
set -e

echo "Step 1/10: Creating directories..."
mkdir -p $AppDir
cd $AppDir

echo "Step 2/10: Updating system..."
apt-get update -qq
apt-get upgrade -y -qq

echo "Step 3/10: Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh > /dev/null 2>&1
rm get-docker.sh

echo "Step 4/10: Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-`$(uname -s)-`$(uname -m)" -o /usr/local/bin/docker-compose 2>/dev/null
chmod +x /usr/local/bin/docker-compose

echo "Step 5/10: Starting Docker..."
systemctl start docker
systemctl enable docker > /dev/null 2>&1

echo "Step 6/10: Cloning repository..."
cd /opt
rm -rf fichaje
git clone $RepoUrl fichaje
cd fichaje

echo "Step 7/10: Installing Java and Maven..."
apt-get install -y -qq openjdk-11-jdk maven

echo "Step 8/10: Building backend (this may take 5-10 minutes)..."
cd $AppDir/apps/fichaje-be
mvn clean package -DskipTests -q

echo "Step 9/10: Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash - > /dev/null 2>&1
apt-get install -y -qq nodejs

echo "Step 10/10: Building frontend..."
cd $AppDir/apps/fichaje-fe
npm install > /dev/null 2>&1
npm run build -- --prod > /dev/null 2>&1

echo "✓ Pre-deployment steps completed"
echo "Now generating SSL certificate..."

apt-get install -y -qq certbot python3-certbot-nginx

certbot certonly --standalone \
    -d fichajes.biedma.com \
    --non-interactive \
    --agree-tos \
    -m admin@fichajes.biedma.com 2>/dev/null || echo "Certificate may already exist"

echo "Generating keystore..."
cd $AppDir
openssl pkcs12 -export \
    -in /etc/letsencrypt/live/fichajes.biedma.com/fullchain.pem \
    -inkey /etc/letsencrypt/live/fichajes.biedma.com/privkey.pem \
    -out $AppDir/fichajes-keystore.p12 \
    -name fichaje \
    -passout pass:$env:SSL_KEYSTORE_PASSWORD 2>/dev/null || true

echo "Starting Docker Compose..."
docker-compose -f docker-compose-prod.yml up -d

echo "Waiting for services to start (30 seconds)..."
sleep 30

echo "✓ Deployment complete!"
docker-compose -f docker-compose-prod.yml ps
"@

Write-Success "Commands prepared"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 3: Execute remote deployment
# ═══════════════════════════════════════════════════════════════════════════
Write-Header "🚀 EXECUTING DEPLOYMENT"

Write-Host "This will take 15-30 minutes (building backend and frontend)..."
Write-Host ""

$remoteScript | ssh $VpsHost

# ═══════════════════════════════════════════════════════════════════════════
# STEP 4: Create .env file on remote
# ═══════════════════════════════════════════════════════════════════════════
Write-Header "⚙️  CONFIGURING ENVIRONMENT"

$envFileContent = @"
APP_PORT=8080
APP_SSL_PORT=8443
DB_PORT=3306
ENABLE_SSL=true
DOMAIN=fichajes.biedma.com
LETSENCRYPT_EMAIL=admin@fichajes.biedma.com
MYSQL_ROOT_PASSWORD=$env:MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=db_fichajespi_prod
MYSQL_USER=fichajes_prod
MYSQL_PASSWORD=$env:MYSQL_PASSWORD
MYSQL_INITDB_SKIP_TZINFO=yes
TZ=Europe/Madrid
IP=fichajes.biedma.com
CLIENT_URL=https://fichajes.biedma.com
APP_DOMAIN=fichajes.biedma.com
APP_URL=https://fichajes.biedma.com
JWT_SECRET=$env:JWT_SECRET
JWT_EXPIRATION=36000000
JWT_REFRESH_EXPIRATION=604800000
SSL_KEYSTORE_PASSWORD=$env:SSL_KEYSTORE_PASSWORD
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

# Upload .env via SSH
$envFileContent | ssh $VpsHost "cat > $AppDir/.env"
Write-Success "Environment file created"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 5: Verification
# ═══════════════════════════════════════════════════════════════════════════
Write-Header "✅ FINAL VERIFICATION"

Write-Host "Checking services..."
ssh $VpsHost "cd $AppDir && docker-compose -f docker-compose-prod.yml ps"

Write-Host ""
Write-Success "Deployment completed successfully!"
Write-Host ""
Write-Host "Access URLs:" -ForegroundColor Cyan
Write-Host "  Application:  https://fichajes.biedma.com"
Write-Host "  Grafana:      http://87.106.125.173:3000 (admin/admin123)"
Write-Host "  Prometheus:   http://87.106.125.173:9090"
Write-Host "  API Health:   https://fichajes.biedma.com/actuator/health"
Write-Host ""
Write-Host "Useful commands:" -ForegroundColor Cyan
Write-Host "  View logs:    ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose logs -f backend'"
Write-Host "  Check status: ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose ps'"
Write-Host "  Restart:      ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose restart'"
