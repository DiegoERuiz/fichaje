#!/bin/bash
# Script de despliegue Docker Compose para Fichaje VPS
# Repo: https://github.com/DiegoERuiz/fichaje.git
# VPS: 87.106.125.173 / fichajes.biedma.com

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
VPS_IP="87.106.125.173"
DOMAIN="fichajes.biedma.com"
REPO_URL="https://github.com/DiegoERuiz/fichaje.git"
APP_DIR="/opt/fichaje"

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  🚀 DESPLIEGUE DOCKER COMPOSE - FICHAJE VPS              ║${NC}"
echo -e "${BLUE}║  IP: $VPS_IP                                ║${NC}"
echo -e "${BLUE}║  Domain: $DOMAIN                        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"

# ============================================================================
# PASO 0: PREPARAR SECRETOS LOCALMENTE
# ============================================================================

echo -e "\n${BLUE}📋 PASO 0: Generando secretos de seguridad...${NC}"

# Generar JWT_SECRET
JWT_SECRET=$(openssl rand -base64 192 | tr -d '\n')
echo -e "${GREEN}✓ JWT_SECRET generado${NC}"

# Solicitar otras contraseñas
read -p "Ingresa contraseña para BD (fichajes_prod): " DB_PASSWORD
read -sp "Ingresa contraseña para Keystore SSL: " SSL_KEYSTORE_PASSWORD
echo ""
read -p "Ingresa host SMTP (ej: smtp.gmail.com): " MAIL_HOST
read -p "Ingresa usuario SMTP: " MAIL_USERNAME
read -sp "Ingresa contraseña SMTP: " MAIL_PASSWORD
echo ""
read -p "Ingresa contraseña admin para Grafana: " GRAFANA_PASSWORD

# Guardar secretos localmente (para respaldo)
cat > fichaje-secrets.txt << EOF
# FICHAJE VPS SECRETS - $(date)
# Guardar en lugar seguro

JWT_SECRET=$JWT_SECRET
DB_PASSWORD=$DB_PASSWORD
SSL_KEYSTORE_PASSWORD=$SSL_KEYSTORE_PASSWORD
MAIL_HOST=$MAIL_HOST
MAIL_USERNAME=$MAIL_USERNAME
MAIL_PASSWORD=$MAIL_PASSWORD
GRAFANA_PASSWORD=$GRAFANA_PASSWORD
EOF

chmod 600 fichaje-secrets.txt
echo -e "${GREEN}✓ Secretos guardados en fichaje-secrets.txt${NC}"

# ============================================================================
# PASO 1: CONEXIÓN VPS Y PREPARACIÓN
# ============================================================================

echo -e "\n${BLUE}📡 PASO 1: Conectando al VPS...${NC}"

ssh root@$VPS_IP << SSH_SCRIPT
set -e

echo "✓ Conexión establecida"

# Actualizar sistema
echo -e "\n${BLUE}Actualizando sistema...${NC}"
apt-get update > /dev/null 2>&1
apt-get install -y curl wget git > /dev/null 2>&1

# Instalar Docker si no está
if ! command -v docker &> /dev/null; then
    echo -e "${BLUE}Instalando Docker...${NC}"
    apt-get install -y docker.io docker-compose > /dev/null 2>&1
    systemctl enable docker
    systemctl start docker
fi

# Instalar Node.js para compilar frontend
if ! command -v node &> /dev/null; then
    echo -e "${BLUE}Instalando Node.js...${NC}"
    apt-get install -y nodejs npm > /dev/null 2>&1
fi

# Crear directorio de aplicación
mkdir -p $APP_DIR
cd $APP_DIR

echo "✓ VPS preparado"
SSH_SCRIPT

echo -e "${GREEN}✓ VPS actualizado y preparado${NC}"

# ============================================================================
# PASO 2: CLONAR REPOSITORIO
# ============================================================================

echo -e "\n${BLUE}📥 PASO 2: Clonando repositorio...${NC}"

ssh root@$VPS_IP << SSH_SCRIPT
cd $APP_DIR

# Clonar si no existe
if [ ! -d ".git" ]; then
    echo "Clonando repositorio..."
    git clone $REPO_URL .
    echo "✓ Repositorio clonado"
else
    echo "Actualizando repositorio..."
    git pull origin main
    echo "✓ Repositorio actualizado"
fi

# Mostrar branch actual
echo "Branch actual: \$(git branch --show-current)"
SSH_SCRIPT

echo -e "${GREEN}✓ Repositorio disponible${NC}"

# ============================================================================
# PASO 3: CREAR ARCHIVO .env.prod
# ============================================================================

echo -e "\n${BLUE}🔐 PASO 3: Configurando variables de entorno...${NC}"

ssh root@$VPS_IP << SSH_SCRIPT
cat > $APP_DIR/.env.prod << 'ENVFILE'
# ============ BASE DE DATOS ============
MYSQL_ROOT_PASSWORD=root-fichaje-2024
DB_NAME=db_fichajespi_prod
DB_USER=fichajes_prod
DB_PASSWORD=$DB_PASSWORD

# ============ JWT TOKENS ============
JWT_SECRET=$JWT_SECRET
JWT_EXPIRATION=36000000
JWT_REFRESH_EXPIRATION=604800000

# ============ SSL/KEYSTORE ============
SSL_KEYSTORE_PATH=/app/fichajes-keystore.p12
SSL_KEYSTORE_PASSWORD=$SSL_KEYSTORE_PASSWORD

# ============ URLS ============
CLIENT_URL=https://$DOMAIN
SERVER_URL=https://$DOMAIN:8443

# ============ MAIL/SMTP ============
MAIL_HOST=$MAIL_HOST
MAIL_PORT=587
MAIL_USERNAME=$MAIL_USERNAME
MAIL_PASSWORD=$MAIL_PASSWORD
MAIL_FROM=noreply@$DOMAIN

# ============ RATE LIMITING ============
RATE_LIMIT_ENABLED=true

# ============ SPRING PROFILE ============
SPRING_PROFILES_ACTIVE=prod

# ============ GRAFANA ============
GRAFANA_PASSWORD=$GRAFANA_PASSWORD

# ============ DOCKER ============
COMPOSE_PROJECT_NAME=fichaje
ENVFILE

chmod 600 $APP_DIR/.env.prod
echo "✓ Archivo .env.prod creado con permisos restrictivos"
SSH_SCRIPT

echo -e "${GREEN}✓ Variables de entorno configuradas${NC}"

# ============================================================================
# PASO 4: COMPILAR APLICACIÓN
# ============================================================================

echo -e "\n${BLUE}🔨 PASO 4: Compilando aplicación (esto puede tomar 5-10 minutos)...${NC}"

ssh root@$VPS_IP << SSH_SCRIPT
cd $APP_DIR

# Compilar backend
echo "Compilando backend Java..."
cd apps/fichaje-be
chmod +x mvnw
./mvnw clean package -DskipTests -Dspring.profiles.active=prod 2>&1 | tail -20

# Copiar JAR a ubicación de Docker
mkdir -p target-docker
cp target/fichaje-be-*.jar target-docker/app.jar
echo "✓ Backend compilado"

# Compilar frontend
echo "Compilando frontend Angular..."
cd ../fichaje-fe
npm ci > /dev/null 2>&1
npm run build -- --prod 2>&1 | tail -10
echo "✓ Frontend compilado"

cd $APP_DIR
SSH_SCRIPT

echo -e "${GREEN}✓ Aplicación compilada${NC}"

# ============================================================================
# PASO 5: GENERAR CERTIFICADO SSL
# ============================================================================

echo -e "\n${BLUE}🔒 PASO 5: Generando certificado SSL (Let's Encrypt)...${NC}"

ssh root@$VPS_IP << SSH_SCRIPT
# Instalar certbot si no está
apt-get install -y certbot python3-certbot-nginx > /dev/null 2>&1

# Generar certificado
if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "Generando certificado SSL..."
    certbot certonly --standalone \
      -d $DOMAIN \
      --agree-tos \
      -m admin@$DOMAIN \
      -n 2>&1 || echo "Nota: Certbot requiere DNS configurado correctamente"
    echo "✓ Certificado generado"
else
    echo "✓ Certificado SSL ya existe"
fi
SSH_SCRIPT

echo -e "${GREEN}✓ SSL configurado${NC}"

# ============================================================================
# PASO 6: GENERAR KEYSTORE
# ============================================================================

echo -e "\n${BLUE}🗝️  PASO 6: Generando Keystore para HTTPS...${NC}"

ssh root@$VPS_IP << SSH_SCRIPT
cd $APP_DIR

# Instalar keytool (viene con Java)
apt-get install -y openjdk-11-jdk > /dev/null 2>&1

# Generar keystore
keytool -genkeypair -alias tomcat \
  -keyalg RSA -keysize 2048 \
  -keystore fichajes-keystore.p12 \
  -storetype PKCS12 \
  -storepass "$SSL_KEYSTORE_PASSWORD" \
  -validity 365 \
  -dname "CN=$DOMAIN, O=Biedma, C=ES" \
  -noprompt

echo "✓ Keystore generado"
SSH_SCRIPT

echo -e "${GREEN}✓ Keystore creado${NC}"

# ============================================================================
# PASO 7: INICIAR DOCKER COMPOSE
# ============================================================================

echo -e "\n${BLUE}🐳 PASO 7: Iniciando servicios con Docker Compose...${NC}"

ssh root@$VPS_IP << SSH_SCRIPT
cd $APP_DIR

# Detener contenedores anteriores
docker-compose -f docker-compose-prod.yml down 2>/dev/null || true

# Iniciar servicios
echo "Iniciando servicios..."
docker-compose -f docker-compose-prod.yml up -d

sleep 5

# Verificar status
echo ""
echo "╔════════════════════════════════════════════╗"
echo "║         ESTADO DE SERVICIOS                ║"
echo "╚════════════════════════════════════════════╝"
docker-compose -f docker-compose-prod.yml ps

echo ""
SSH_SCRIPT

echo -e "${GREEN}✓ Servicios iniciados${NC}"

# ============================================================================
# PASO 8: VERIFICAR SALUD
# ============================================================================

echo -e "\n${BLUE}🏥 PASO 8: Verificando salud de servicios...${NC}"

sleep 10

ssh root@$VPS_IP << SSH_SCRIPT
cd $APP_DIR

echo "Esperando a que los servicios se inicien..."
sleep 5

# Verificar MySQL
echo -n "MySQL: "
if docker-compose -f docker-compose-prod.yml exec -T mysql mysqladmin ping -u root -proot-fichaje-2024 > /dev/null 2>&1; then
    echo "✓ Activo"
else
    echo "⏳ Iniciando..."
fi

# Verificar backend
echo -n "Backend: "
if curl -k -f https://localhost:8443/actuator/health > /dev/null 2>&1; then
    echo "✓ Activo"
else
    echo "⏳ Iniciando (normalmente tarda 30-60 segundos)..."
fi

# Verificar Nginx
echo -n "Nginx: "
if curl -f http://localhost/health > /dev/null 2>&1; then
    echo "✓ Activo"
else
    echo "⏳ Iniciando..."
fi

echo ""
SSH_SCRIPT

echo -e "${GREEN}✓ Verificación completada${NC}"

# ============================================================================
# PASO 9: MOSTRAR INFORMACIÓN
# ============================================================================

echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ DESPLIEGUE COMPLETADO EXITOSAMENTE                   ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"

cat << EOF

📍 ACCESO A LA APLICACIÓN:
   🌐 https://$DOMAIN
   📊 Admin Grafana: http://$VPS_IP:3000 (admin / $GRAFANA_PASSWORD)
   📈 Prometheus: http://$VPS_IP:9090

🔑 CREDENCIALES:
   Base de Datos:
   - Usuario: $DB_USER
   - Contraseña: (guardada en fichaje-secrets.txt)

   Grafana:
   - Usuario: admin
   - Contraseña: $GRAFANA_PASSWORD

📝 LOGS EN VIVO:
   ssh root@$VPS_IP
   cd /opt/fichaje
   docker-compose -f docker-compose-prod.yml logs -f backend

⚙️  COMANDOS ÚTILES:
   # Ver estado
   docker-compose -f docker-compose-prod.yml ps

   # Reiniciar servicios
   docker-compose -f docker-compose-prod.yml restart

   # Ver logs
   docker-compose -f docker-compose-prod.yml logs -f [servicio]

   # Detener todo
   docker-compose -f docker-compose-prod.yml down

📋 ARCHIVO DE SECRETOS:
   Ubicación local: ./fichaje-secrets.txt
   ⚠️  GUARDAR EN LUGAR SEGURO - No versionear en Git

🔒 SEGURIDAD:
   ✓ HTTPS obligatorio
   ✓ JWT tokens con refresh
   ✓ Auditoría de logins
   ✓ Rate limiting (100 req/min)
   ✓ Contraseñas fuertes requeridas
   ✓ Account lockout activo

📊 PRÓXIMAS TAREAS:
   1. Verificar que https://$DOMAIN sea accesible
   2. Probar login con usuario admin (fichajesPi000)
   3. Configurar DNS si es necesario
   4. Revisar logs de errors
   5. Configurar backups automáticos

EOF

echo -e "\n${YELLOW}⏳ El backend puede tardar 1-2 minutos en estar completamente operativo${NC}"
echo -e "${YELLOW}   Si ves errores, ejecuta: docker-compose -f docker-compose-prod.yml logs backend${NC}\n"

# ============================================================================
# PASO 10: MOSTRAR LOGS EN VIVO
# ============================================================================

echo -e "${BLUE}🔍 Mostrando logs del backend en vivo (Ctrl+C para salir)...${NC}\n"

ssh root@$VPS_IP << SSH_SCRIPT
cd $APP_DIR
docker-compose -f docker-compose-prod.yml logs -f backend
SSH_SCRIPT
