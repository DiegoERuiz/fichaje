#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# FICHAJE - DESPLIEGUE AUTOMÁTICO EN VPS CON DOCKER COMPOSE
# ═══════════════════════════════════════════════════════════════════════════
set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
VPS_IP="87.106.125.173"
VPS_USER="root"
VPS_HOST="${VPS_USER}@${VPS_IP}"
APP_DIR="/opt/fichaje"
REPO_URL="https://github.com/DiegoERuiz/fichaje.git"

# Función para imprimir con color
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_step() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════
# PASO 0: Verificaciones previas
# ═══════════════════════════════════════════════════════════════════════════
print_header "🔍 VERIFICACIONES PREVIAS"

if ! command -v ssh &> /dev/null; then
    print_error "SSH no está instalado"
    exit 1
fi
print_step "SSH disponible"

if ! command -v scp &> /dev/null; then
    print_error "SCP no está disponible"
    exit 1
fi
print_step "SCP disponible"

# Verificar conectividad
echo -n "Verificando conectividad a VPS..."
if ssh -o ConnectTimeout=5 "${VPS_HOST}" "echo 'OK'" > /dev/null 2>&1; then
    print_step "Conectividad a VPS: OK"
else
    print_error "No se puede conectar a ${VPS_HOST}"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════
# PASO 1: Leer secretos (con valores por defecto del .env.prod)
# ═══════════════════════════════════════════════════════════════════════════
print_header "🔐 CONFIGURACIÓN DE SECRETOS"

# Leer de .env.prod si existe
if [ -f "deploy/prod/.env" ]; then
    # Extraer valores del .env.prod actual
    JWT_SECRET=$(grep "^JWT_SECRET=" deploy/prod/.env | cut -d '=' -f2 | xargs)
    DB_PASSWORD=$(grep "^MYSQL_PASSWORD=" deploy/prod/.env | cut -d '=' -f2 | xargs)
    MYSQL_ROOT_PASSWORD=$(grep "^MYSQL_ROOT_PASSWORD=" deploy/prod/.env | cut -d '=' -f2 | xargs)
    SSL_KEYSTORE_PASSWORD=$(grep "^SSL_KEYSTORE_PASSWORD=" deploy/prod/.env | cut -d '=' -f2 | xargs)
    
    print_step "Secretos cargados desde deploy/prod/.env"
else
    print_error "Archivo deploy/prod/.env no encontrado"
    exit 1
fi

# Validar que tenemos los secretos
if [ -z "$JWT_SECRET" ] || [ -z "$DB_PASSWORD" ] || [ -z "$MYSQL_ROOT_PASSWORD" ] || [ -z "$SSL_KEYSTORE_PASSWORD" ]; then
    print_error "Faltan secretos en deploy/prod/.env"
    exit 1
fi

echo "JWT_SECRET: ${JWT_SECRET:0:20}..."
echo "DB_PASSWORD: ****"
echo "MYSQL_ROOT_PASSWORD: ****"
echo "SSL_KEYSTORE_PASSWORD: ****"

# ═══════════════════════════════════════════════════════════════════════════
# PASO 2: Preparar archivos para despliegue
# ═══════════════════════════════════════════════════════════════════════════
print_header "📦 PREPARANDO ARCHIVOS DE DESPLIEGUE"

# Crear directorio temporal
TEMP_DIR=$(mktemp -d)
print_step "Directorio temporal: $TEMP_DIR"

# Copiar archivos necesarios
cp docker-compose-prod.yml "$TEMP_DIR/"
cp init-db.sql "$TEMP_DIR/"
cp apps/fichaje-be/Dockerfile-prod "$TEMP_DIR/Dockerfile"
cp deploy/prod/nginx.conf "$TEMP_DIR/"
cp deploy/prod/.env "$TEMP_DIR/.env.prod"

print_step "Archivos copiados a directorio temporal"

# ═══════════════════════════════════════════════════════════════════════════
# PASO 3: Crear directorio en VPS y subir archivos
# ═══════════════════════════════════════════════════════════════════════════
print_header "🚀 PREPARANDO VPS"

# Crear directorio
ssh "${VPS_HOST}" "mkdir -p ${APP_DIR}"
print_step "Directorio ${APP_DIR} creado en VPS"

# Subir archivo .env.prod
scp "$TEMP_DIR/.env.prod" "${VPS_HOST}:${APP_DIR}/.env"
print_step ".env enviado a VPS"

# ═══════════════════════════════════════════════════════════════════════════
# PASO 4: Actualizar sistema e instalar dependencias
# ═══════════════════════════════════════════════════════════════════════════
print_header "🔧 ACTUALIZANDO SISTEMA E INSTALANDO DEPENDENCIAS"

ssh "${VPS_HOST}" << 'REMOTE_SCRIPT'
set -e

echo "Actualizando sistema..."
apt-get update
apt-get upgrade -y

echo "Instalando Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

echo "Instalando Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "Iniciando Docker..."
systemctl start docker
systemctl enable docker

echo "Verificando instalación..."
docker --version
docker-compose --version
REMOTE_SCRIPT

print_step "Sistema actualizado y dependencias instaladas"

# ═══════════════════════════════════════════════════════════════════════════
# PASO 5: Clonar repositorio
# ═══════════════════════════════════════════════════════════════════════════
print_header "📥 CLONANDO REPOSITORIO"

ssh "${VPS_HOST}" << REMOTE_SCRIPT
set -e
cd ${APP_DIR}

if [ -d ".git" ]; then
    echo "Repositorio ya existe, actualizando..."
    git pull origin main
else
    echo "Clonando repositorio..."
    cd /opt
    git clone ${REPO_URL} fichaje
    cd fichaje
fi

echo "Verificando rama..."
git branch -a
REMOTE_SCRIPT

print_step "Repositorio clonado/actualizado"

# ═══════════════════════════════════════════════════════════════════════════
# PASO 6: Compilar Backend (Maven)
# ═══════════════════════════════════════════════════════════════════════════
print_header "☕ COMPILANDO BACKEND (Maven)"

ssh "${VPS_HOST}" << REMOTE_SCRIPT
set -e
cd ${APP_DIR}/apps/fichaje-be

echo "Instalando Java y Maven..."
apt-get install -y openjdk-11-jdk maven

echo "Compilando backend..."
mvn clean package -DskipTests

echo "Build completado"
ls -lh target/*.jar
REMOTE_SCRIPT

print_step "Backend compilado exitosamente"

# ═══════════════════════════════════════════════════════════════════════════
# PASO 7: Compilar Frontend (Angular)
# ═══════════════════════════════════════════════════════════════════════════
print_header "🅰️  COMPILANDO FRONTEND (Angular)"

ssh "${VPS_HOST}" << REMOTE_SCRIPT
set -e
cd ${APP_DIR}/apps/fichaje-fe

echo "Instalando Node.js y npm..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs

echo "Instalando dependencias..."
npm install

echo "Compilando Angular..."
npm run build -- --prod

echo "Build completado"
ls -lh dist/
REMOTE_SCRIPT

print_step "Frontend compilado exitosamente"

# ═══════════════════════════════════════════════════════════════════════════
# PASO 8: Generar certificado SSL y keystore
# ═══════════════════════════════════════════════════════════════════════════
print_header "🔒 GENERANDO CERTIFICADO SSL"

ssh "${VPS_HOST}" << REMOTE_SCRIPT
set -e
cd ${APP_DIR}

echo "Instalando Certbot..."
apt-get install -y certbot python3-certbot-nginx

echo "Generando certificado Let's Encrypt..."
certbot certonly --standalone \
    -d fichajes.biedma.com \
    --non-interactive \
    --agree-tos \
    -m admin@fichajes.biedma.com

echo "Certificado generado en /etc/letsencrypt/live/fichajes.biedma.com/"

# Extraer certificado y clave
SSL_CERT="/etc/letsencrypt/live/fichajes.biedma.com/fullchain.pem"
SSL_KEY="/etc/letsencrypt/live/fichajes.biedma.com/privkey.pem"

# Generar PKCS12 keystore
openssl pkcs12 -export \
    -in \$SSL_CERT \
    -inkey \$SSL_KEY \
    -out ${APP_DIR}/fichajes-keystore.p12 \
    -name fichaje \
    -passout pass:${SSL_KEYSTORE_PASSWORD}

echo "Keystore generado: ${APP_DIR}/fichajes-keystore.p12"
REMOTE_SCRIPT

print_step "Certificado SSL y keystore generados"

# ═══════════════════════════════════════════════════════════════════════════
# PASO 9: Preparar docker-compose
# ═══════════════════════════════════════════════════════════════════════════
print_header "🐳 PREPARANDO DOCKER COMPOSE"

# Subir docker-compose-prod.yml
scp "$TEMP_DIR/docker-compose-prod.yml" "${VPS_HOST}:${APP_DIR}/"
scp "$TEMP_DIR/Dockerfile" "${VPS_HOST}:${APP_DIR}/apps/fichaje-be/"
scp "$TEMP_DIR/nginx.conf" "${VPS_HOST}:${APP_DIR}/deploy/prod/"
scp "$TEMP_DIR/init-db.sql" "${VPS_HOST}:${APP_DIR}/"

print_step "Archivos Docker enviados"

# ═══════════════════════════════════════════════════════════════════════════
# PASO 10: Iniciar servicios Docker
# ═══════════════════════════════════════════════════════════════════════════
print_header "🚀 INICIANDO SERVICIOS DOCKER"

ssh "${VPS_HOST}" << REMOTE_SCRIPT
set -e
cd ${APP_DIR}

echo "Iniciando Docker Compose..."
docker-compose -f docker-compose-prod.yml up -d

echo "Esperando a que los servicios se inicien..."
sleep 30

echo "Estado de servicios:"
docker-compose -f docker-compose-prod.yml ps

echo "Logs backend (últimas líneas):"
docker-compose -f docker-compose-prod.yml logs backend | tail -20
REMOTE_SCRIPT

print_step "Servicios iniciados exitosamente"

# ═══════════════════════════════════════════════════════════════════════════
# PASO 11: Verificaciones finales
# ═══════════════════════════════════════════════════════════════════════════
print_header "✅ VERIFICACIONES FINALES"

ssh "${VPS_HOST}" << REMOTE_SCRIPT
set -e
cd ${APP_DIR}

echo "Verificando containers..."
docker-compose -f docker-compose-prod.yml ps

echo "Verificando MySQL..."
docker-compose -f docker-compose-prod.yml exec -T mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SHOW DATABASES;"

echo "Verificando conectividad a backend..."
sleep 10
curl -k https://localhost:8443/actuator/health || echo "Backend aún iniciándose..."

REMOTE_SCRIPT

print_step "Verificaciones completadas"

# ═══════════════════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ═══════════════════════════════════════════════════════════════════════════
print_header "🎉 DESPLIEGUE COMPLETADO"

echo ""
echo "Accesos:"
echo -e "  Aplicación:  ${GREEN}https://fichajes.biedma.com${NC}"
echo -e "  Grafana:     ${GREEN}http://87.106.125.173:3000${NC}"
echo -e "  Prometheus: ${GREEN}http://87.106.125.173:9090${NC}"
echo -e "  API Health: ${GREEN}https://fichajes.biedma.com/actuator/health${NC}"
echo ""
echo "Comandos útiles:"
echo "  Ver logs:        ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose logs -f backend'"
echo "  Ver estado:      ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose ps'"
echo "  Reiniciar:       ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose restart'"
echo ""

# Limpiar directorio temporal
rm -rf "$TEMP_DIR"
print_step "Directorio temporal eliminado"

echo -e "${GREEN}✓ ¡Despliegue completado exitosamente!${NC}"
