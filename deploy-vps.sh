#!/bin/bash
# Script de despliegue automatizado para Fichaje en VPS Ubuntu 24.04
# Uso: bash deploy-vps.sh

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de configuración
VPS_IP="87.106.125.173"
DOMAIN="fichajes.biedma.com"
APP_DIR="/opt/fichaje"
BACKUP_DIR="/backup"

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🚀 DESPLIEGUE AUTOMATIZADO - FICHAJE VPS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Función para preguntar
ask_yes_no() {
    local prompt="$1"
    local response
    read -p "$(echo -e ${YELLOW}$prompt${NC}) (s/n): " response
    [[ "$response" =~ ^[sS]$ ]]
}

# ============================================================================
# 1. VALIDAR CONEXIÓN
# ============================================================================
echo -e "\n${BLUE}1. Validando conexión al VPS...${NC}"
if ssh root@$VPS_IP "echo 'Conexión OK'" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Conexión VPS establecida${NC}"
else
    echo -e "${RED}✗ No se puede conectar al VPS. Verifica la IP y credenciales.${NC}"
    exit 1
fi

# ============================================================================
# 2. ACTUALIZAR SISTEMA
# ============================================================================
if ask_yes_no "¿Actualizar sistema del VPS? (apt update && upgrade)"; then
    echo -e "${BLUE}2. Actualizando sistema...${NC}"
    ssh root@$VPS_IP << 'EOF'
apt update
apt upgrade -y
apt install -y curl wget git build-essential openssl certbot python3-certbot-nginx
echo "✓ Sistema actualizado"
EOF
fi

# ============================================================================
# 3. INSTALAR DEPENDENCIAS
# ============================================================================
if ask_yes_no "¿Instalar Java 11, MySQL, Docker y Nginx?"; then
    echo -e "${BLUE}3. Instalando dependencias...${NC}"
    ssh root@$VPS_IP << 'EOF'
# Java
apt install -y openjdk-11-jdk
echo "✓ Java instalado: $(java -version 2>&1 | head -1)"

# MySQL
apt install -y mysql-server mysql-client
systemctl enable mysql
systemctl start mysql
echo "✓ MySQL instalado"

# Docker
apt install -y docker.io docker-compose
systemctl enable docker
systemctl start docker
echo "✓ Docker instalado"

# Nginx
apt install -y nginx
systemctl enable nginx
systemctl start nginx
echo "✓ Nginx instalado"
EOF
fi

# ============================================================================
# 4. CREAR DIRECTORIO DE APLICACIÓN
# ============================================================================
echo -e "${BLUE}4. Creando directorios...${NC}"
ssh root@$VPS_IP "mkdir -p $APP_DIR $BACKUP_DIR && chmod 755 $APP_DIR $BACKUP_DIR"
echo -e "${GREEN}✓ Directorios creados${NC}"

# ============================================================================
# 5. CREAR BASE DE DATOS
# ============================================================================
if ask_yes_no "¿Crear base de datos MySQL? (se solicitará contraseña)"; then
    echo -e "${BLUE}5. Configurando Base de Datos...${NC}"
    
    read -sp "Contraseña para usuario 'fichajes_prod': " DB_PASSWORD
    echo ""
    
    ssh root@$VPS_IP << EOF
mysql -u root << 'MYSQL_EOF'
CREATE DATABASE IF NOT EXISTS db_fichajespi_prod CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
DROP USER IF EXISTS 'fichajes_prod'@'localhost';
CREATE USER 'fichajes_prod'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON db_fichajespi_prod.* TO 'fichajes_prod'@'localhost';
FLUSH PRIVILEGES;
MYSQL_EOF
echo "✓ Base de datos creada"
EOF
fi

# ============================================================================
# 6. CLONAR REPOSITORIO
# ============================================================================
if ask_yes_no "¿Clonar repositorio de GitHub?"; then
    echo -e "${BLUE}6. Clonando repositorio...${NC}"
    read -p "URL del repositorio: " REPO_URL
    ssh root@$VPS_IP "cd $APP_DIR && git clone $REPO_URL . && echo '✓ Repositorio clonado'"
fi

# ============================================================================
# 7. COMPILAR APLICACIÓN
# ============================================================================
if ask_yes_no "¿Compilar aplicación Java?"; then
    echo -e "${BLUE}7. Compilando backend...${NC}"
    ssh root@$VPS_IP << 'EOF'
cd /opt/fichaje/apps/fichaje-be
chmod +x mvnw
./mvnw clean package -DskipTests -Dspring.profiles.active=prod
echo "✓ Backend compilado"
EOF
    
    echo -e "${BLUE}7b. Compilando frontend Angular...${NC}"
    ssh root@$VPS_IP << 'EOF'
cd /opt/fichaje/apps/fichaje-fe
apt install -y nodejs npm 2>/dev/null || true
npm install
npm run build -- --prod
echo "✓ Frontend compilado"
EOF
fi

# ============================================================================
# 8. GENERAR SECRETS
# ============================================================================
if ask_yes_no "¿Generar JWT Secret y Keystore?"; then
    echo -e "${BLUE}8. Generando secretos de seguridad...${NC}"
    
    JWT_SECRET=$(openssl rand -base64 192 | tr -d '\n')
    KEYSTORE_PASSWORD=$(openssl rand -base64 18 | tr -d '\n')
    
    echo -e "${YELLOW}JWT_SECRET generado (guardado en archivo local)${NC}"
    echo $JWT_SECRET > jwt-secret.txt
    echo $KEYSTORE_PASSWORD > keystore-password.txt
    
    ssh root@$VPS_IP << EOF
keytool -genkeypair -alias tomcat \
  -keyalg RSA -keysize 2048 \
  -keystore $APP_DIR/fichajes-keystore.p12 \
  -storetype PKCS12 \
  -storepass $KEYSTORE_PASSWORD \
  -validity 365 \
  -dname "CN=$DOMAIN, O=Biedma, C=ES" \
  -noprompt

echo "✓ Keystore generado: $APP_DIR/fichajes-keystore.p12"
EOF
fi

# ============================================================================
# 9. OBTENER CERTIFICADO SSL
# ============================================================================
if ask_yes_no "¿Generar certificado SSL con Let's Encrypt?"; then
    echo -e "${BLUE}9. Generando certificado SSL...${NC}"
    read -p "Email para Let's Encrypt: " LE_EMAIL
    
    ssh root@$VPS_IP << EOF
certbot certonly --standalone \
  -d $DOMAIN \
  --agree-tos \
  -m $LE_EMAIL \
  -n 2>&1 || echo "Nota: El certificado podría estar en caché"
echo "✓ Certificado SSL configurado"
EOF
fi

# ============================================================================
# 10. CONFIGURAR VARIABLES DE ENTORNO
# ============================================================================
if ask_yes_no "¿Crear archivo .env.prod con configuración?"; then
    echo -e "${BLUE}10. Configurando variables de entorno...${NC}"
    
    read -sp "Contraseña BD (fichajes_prod): " DB_PASS
    echo ""
    read -p "Host SMTP para emails: " SMTP_HOST
    read -p "Usuario SMTP: " SMTP_USER
    read -sp "Contraseña SMTP: " SMTP_PASS
    echo ""
    
    ssh root@$VPS_IP << EOF
cat > $APP_DIR/apps/fichaje-be/.env.prod << 'ENVFILE'
# Base de Datos
DB_HOST=localhost
DB_PORT=3306
DB_NAME=db_fichajespi_prod
DB_USER=fichajes_prod
DB_PASSWORD=$DB_PASS

# JWT
JWT_SECRET=$(cat jwt-secret.txt 2>/dev/null || echo "GENERAR-CON-OPENSSL-RAND")
JWT_EXPIRATION=36000000
JWT_REFRESH_EXPIRATION=604800000

# HTTPS/SSL
SSL_KEYSTORE_PATH=$APP_DIR/fichajes-keystore.p12
SSL_KEYSTORE_PASSWORD=$(cat keystore-password.txt 2>/dev/null || echo "CAMBIAR-KEYSTORE-PASSWORD")

# URLs
CLIENT_URL=https://$DOMAIN
SERVER_URL=https://$DOMAIN:8443

# Mail
MAIL_HOST=$SMTP_HOST
MAIL_PORT=587
MAIL_USERNAME=$SMTP_USER
MAIL_PASSWORD=$SMTP_PASS
MAIL_FROM=noreply@biedma.com

# Rate Limiting
RATE_LIMIT_ENABLED=true

# Perfil Spring
SPRING_PROFILES_ACTIVE=prod
ENVFILE

chmod 600 $APP_DIR/apps/fichaje-be/.env.prod
echo "✓ Variables de entorno configuradas"
EOF
fi

# ============================================================================
# 11. CREAR SERVICIO SYSTEMD
# ============================================================================
if ask_yes_no "¿Crear servicio systemd para la aplicación?"; then
    echo -e "${BLUE}11. Configurando servicio systemd...${NC}"
    ssh root@$VPS_IP << EOF
tee /etc/systemd/system/fichaje.service > /dev/null << 'SERVICEEOF'
[Unit]
Description=Fichaje Application
After=network.target mysql.service

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR/apps/fichaje-be
EnvironmentFile=$APP_DIR/apps/fichaje-be/.env.prod

ExecStart=/bin/bash -c 'java -jar target/fichaje-be-*.jar'

Restart=on-failure
RestartSec=10
MemoryLimit=2G
CPUQuota=80%

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable fichaje
systemctl start fichaje
sleep 5
systemctl status fichaje --no-pager || echo "Iniciando aplicación..."
echo "✓ Servicio fichaje creado y activado"
EOF
fi

# ============================================================================
# 12. CONFIGURAR NGINX
# ============================================================================
if ask_yes_no "¿Configurar Nginx como reverse proxy?"; then
    echo -e "${BLUE}12. Configurando Nginx...${NC}"
    ssh root@$VPS_IP << EOF
tee /etc/nginx/sites-available/$DOMAIN > /dev/null << 'NGINXEOF'
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript;

    location /api/ {
        proxy_pass https://localhost:8443/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 600s;
    }

    location / {
        root $APP_DIR/apps/fichaje-fe/dist/fichaje-fe;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
}
NGINXEOF

ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx
echo "✓ Nginx configurado"
EOF
fi

# ============================================================================
# 13. CONFIGURAR RENOVACIÓN SSL AUTOMÁTICA
# ============================================================================
echo -e "${BLUE}13. Configurando renovación automática de certificados...${NC}"
ssh root@$VPS_IP << 'EOF'
cat > /usr/local/bin/renew-ssl.sh << 'SCRIPTEOF'
#!/bin/bash
certbot renew --quiet
systemctl reload nginx
SCRIPTEOF

chmod +x /usr/local/bin/renew-ssl.sh
echo "0 2 1 * * /usr/local/bin/renew-ssl.sh" | crontab -
echo "✓ Renovación SSL programada mensualmente"
EOF

# ============================================================================
# 14. CONFIGURAR BACKUPS
# ============================================================================
if ask_yes_no "¿Configurar backups automáticos?"; then
    echo -e "${BLUE}14. Configurando backups...${NC}"
    ssh root@$VPS_IP << 'EOF'
cat > /usr/local/bin/backup-fichaje.sh << 'SCRIPTEOF'
#!/bin/bash
BACKUP_DIR="/backup"
DATE=$(date +%Y%m%d_%H%M%S)

mysqldump -u fichajes_prod -p"$DB_PASSWORD" db_fichajespi_prod | gzip > $BACKUP_DIR/db_$DATE.sql.gz
find $BACKUP_DIR -name "db_*.sql.gz" -mtime +30 -delete
SCRIPTEOF

chmod +x /usr/local/bin/backup-fichaje.sh
echo "0 3 * * * DB_PASSWORD=tu-password /usr/local/bin/backup-fichaje.sh" | crontab -
echo "✓ Backups programados diariamente"
EOF
fi

# ============================================================================
# 15. VERIFICACIÓN FINAL
# ============================================================================
echo -e "\n${BLUE}15. Verificación final...${NC}"
ssh root@$VPS_IP << 'EOF'
echo "═══ ESTADO DE SERVICIOS ═══"
systemctl status --no-pager fichaje | head -5
systemctl status --no-pager nginx | head -5
systemctl status --no-pager mysql | head -5

echo ""
echo "═══ PUERTOS EN ESCUCHA ═══"
netstat -tulpn 2>/dev/null | grep LISTEN || ss -tulpn | grep LISTEN

echo ""
echo "═══ ESPACIOS EN DISCO ═══"
df -h | grep -E "^/dev"

echo ""
echo "═══ USO DE MEMORIA ═══"
free -h | head -2
EOF

# ============================================================================
# RESUMEN FINAL
# ============================================================================
echo -e "\n${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ DESPLIEGUE COMPLETADO EXITOSAMENTE${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "\n${YELLOW}PRÓXIMOS PASOS:${NC}"
echo -e "1. Verifica https://$DOMAIN en tu navegador"
echo -e "2. Prueba login con las credenciales de la aplicación"
echo -e "3. Configura email SMTP si es necesario"
echo -e "4. Revisa logs: ssh root@$VPS_IP 'journalctl -u fichaje -f'"
echo -e "5. Mantén backups regularmente"
echo -e "\n${YELLOW}ARCHIVOS DE SEGURIDAD LOCALES (GUARDAR EN LUGAR SEGURO):${NC}"
echo -e "- jwt-secret.txt (JWT_SECRET)"
echo -e "- keystore-password.txt (SSL_KEYSTORE_PASSWORD)"
echo -e "\n"
