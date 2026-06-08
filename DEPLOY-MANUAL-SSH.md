# Fichaje Deploy - Comandos SSH para ejecutar en VPS
# Ejecuta estos comandos uno por uno en la terminal SSH

# ═══════════════════════════════════════════════════════════════════════════
# 1. CONECTAR A VPS
# ═══════════════════════════════════════════════════════════════════════════
ssh root@87.106.125.173

# ═══════════════════════════════════════════════════════════════════════════
# 2. CREAR DIRECTORIO Y ENTRAR
# ═══════════════════════════════════════════════════════════════════════════
mkdir -p /opt/fichaje
cd /opt/fichaje

# ═══════════════════════════════════════════════════════════════════════════
# 3. ACTUALIZAR SISTEMA
# ═══════════════════════════════════════════════════════════════════════════
apt-get update
apt-get upgrade -y

# ═══════════════════════════════════════════════════════════════════════════
# 4. INSTALAR DOCKER
# ═══════════════════════════════════════════════════════════════════════════
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# ═══════════════════════════════════════════════════════════════════════════
# 5. INSTALAR DOCKER COMPOSE
# ═══════════════════════════════════════════════════════════════════════════
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# ═══════════════════════════════════════════════════════════════════════════
# 6. INICIAR DOCKER
# ═══════════════════════════════════════════════════════════════════════════
systemctl start docker
systemctl enable docker

# ═══════════════════════════════════════════════════════════════════════════
# 7. VERIFICAR INSTALACIÓN
# ═══════════════════════════════════════════════════════════════════════════
docker --version
docker-compose --version

# ═══════════════════════════════════════════════════════════════════════════
# 8. CLONAR REPOSITORIO
# ═══════════════════════════════════════════════════════════════════════════
cd /opt
git clone https://github.com/DiegoERuiz/fichaje.git fichaje
cd fichaje

# ═══════════════════════════════════════════════════════════════════════════
# 9. INSTALAR JAVA 11 (para Maven build)
# ═══════════════════════════════════════════════════════════════════════════
apt-get install -y openjdk-11-jdk maven

# ═══════════════════════════════════════════════════════════════════════════
# 10. COMPILAR BACKEND (Maven)
# ═══════════════════════════════════════════════════════════════════════════
cd /opt/fichaje/apps/fichaje-be
mvn clean package -DskipTests
ls -lh target/*.jar

# ═══════════════════════════════════════════════════════════════════════════
# 11. INSTALAR NODE.JS (para Angular build)
# ═══════════════════════════════════════════════════════════════════════════
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# ═══════════════════════════════════════════════════════════════════════════
# 12. COMPILAR FRONTEND (Angular)
# ═══════════════════════════════════════════════════════════════════════════
cd /opt/fichaje/apps/fichaje-fe
npm install
npm run build -- --prod
ls -lh dist/

# ═══════════════════════════════════════════════════════════════════════════
# 13. GENERAR CERTIFICADO SSL CON CERTBOT
# ═══════════════════════════════════════════════════════════════════════════
apt-get install -y certbot python3-certbot-nginx

certbot certonly --standalone \
    -d fichajes.biedma.com \
    --non-interactive \
    --agree-tos \
    -m admin@fichajes.biedma.com

# ═══════════════════════════════════════════════════════════════════════════
# 14. GENERAR KEYSTORE PKCS12 PARA HTTPS
# ═══════════════════════════════════════════════════════════════════════════
cd /opt/fichaje

# REEMPLAZA "gkZJWOo3fP-SaiMM" CON TU SSL_KEYSTORE_PASSWORD
SSL_KEYSTORE_PASSWORD="gkZJWOo3fP-SaiMM"

openssl pkcs12 -export \
    -in /etc/letsencrypt/live/fichajes.biedma.com/fullchain.pem \
    -inkey /etc/letsencrypt/live/fichajes.biedma.com/privkey.pem \
    -out /opt/fichaje/fichajes-keystore.p12 \
    -name fichaje \
    -passout pass:${SSL_KEYSTORE_PASSWORD}

# Verificar que se creó correctamente
ls -lh /opt/fichaje/fichajes-keystore.p12

# ═══════════════════════════════════════════════════════════════════════════
# 15. CREAR .env CON LOS SECRETOS
# ═══════════════════════════════════════════════════════════════════════════
cat > /opt/fichaje/.env << 'EOF'
# 🌐 Configuración Fichaje - Producción
APP_PORT=8080
APP_SSL_PORT=8443
DB_PORT=3306

# SSL
ENABLE_SSL=true
DOMAIN=fichajes.biedma.com
LETSENCRYPT_EMAIL=admin@fichajes.biedma.com

# Base de datos
MYSQL_ROOT_PASSWORD=iM5H3WBfwE1VujQk
MYSQL_DATABASE=db_fichajespi_prod
MYSQL_USER=fichajes_prod
MYSQL_PASSWORD=BKLy0KAk4LUXrHBU
MYSQL_INITDB_SKIP_TZINFO=yes
TZ=Europe/Madrid

# URLs
IP=fichajes.biedma.com
CLIENT_URL=https://fichajes.biedma.com
APP_DOMAIN=fichajes.biedma.com
APP_URL=https://fichajes.biedma.com

# JWT
JWT_SECRET=RzQBHEY6ySjY20MbnJZRSo3Gqf9BW4TkGUAROdMktlUbbV44LykPaow5nj1FdmBFrxO9fBIBV9oB4Bcq9r0PUmLNCVMHI-a25r0wlLpXBl3svYlxwVprJWQXjodELw4R9Ln-Tv9xtob2taddty2VRNuglo8sscJpJF5iD8F15ubT3pdy9UwXxJzgGiR3Dblh
JWT_EXPIRATION=36000000
JWT_REFRESH_EXPIRATION=604800000

# SSL Keystore
SSL_KEYSTORE_PASSWORD=gkZJWOo3fP-SaiMM
SSL_KEYSTORE_ALIAS=fichaje
KEYSTORE_PATH=/opt/fichaje/fichajes-keystore.p12

# Mail (opcional)
SPRING_MAIL_HOST=smtp.gmail.com
SPRING_MAIL_PORT=587
SPRING_MAIL_USERNAME=noreply@fichajes.biedma.com
SPRING_MAIL_PASSWORD=dummy
SPRING_MAIL_PROPERTIES_MAIL_SMTP_AUTH=true
SPRING_MAIL_PROPERTIES_MAIL_SMTP_STARTTLS_ENABLE=true

# Redis
REDIS_HOST=redis
REDIS_PORT=6379

# Prometheus & Grafana
PROMETHEUS_PORT=9090
GRAFANA_PASSWORD=admin123
GRAFANA_ADMIN_USER=admin

# Spring Boot
SPRING_PROFILES_ACTIVE=prod
SPRING_JPA_HIBERNATE_DDL_AUTO=validate

# Logging
LOGGING_LEVEL_ROOT=WARN
LOGGING_LEVEL_ORG_SPRINGFRAMEWORK=WARN
EOF

# Verificar que se creó
cat /opt/fichaje/.env

# ═══════════════════════════════════════════════════════════════════════════
# 16. INICIAR DOCKER COMPOSE
# ═══════════════════════════════════════════════════════════════════════════
cd /opt/fichaje
docker-compose -f docker-compose-prod.yml up -d

# ═══════════════════════════════════════════════════════════════════════════
# 17. ESPERAR A QUE LOS SERVICIOS SE INICIEN
# ═══════════════════════════════════════════════════════════════════════════
echo "Esperando 30 segundos a que los servicios se inicien..."
sleep 30

# ═══════════════════════════════════════════════════════════════════════════
# 18. VERIFICAR ESTADO
# ═══════════════════════════════════════════════════════════════════════════
docker-compose -f docker-compose-prod.yml ps
docker-compose -f docker-compose-prod.yml logs backend | tail -20

# ═══════════════════════════════════════════════════════════════════════════
# 19. VERIFICAR MySQL
# ═══════════════════════════════════════════════════════════════════════════
docker-compose -f docker-compose-prod.yml exec -T mysql mysql -u root -piM5H3WBfwE1VujQk -e "SHOW DATABASES;"

# ═══════════════════════════════════════════════════════════════════════════
# 20. VERIFICAR API BACKEND
# ═══════════════════════════════════════════════════════════════════════════
curl -k https://localhost:8443/actuator/health

# ═══════════════════════════════════════════════════════════════════════════
# ✅ LISTO - ACCESOS
# ═══════════════════════════════════════════════════════════════════════════
# Aplicación:  https://fichajes.biedma.com
# Grafana:     http://87.106.125.173:3000 (admin/admin123)
# Prometheus: http://87.106.125.173:9090
# API Health: https://fichajes.biedma.com/actuator/health

# ═══════════════════════════════════════════════════════════════════════════
# COMANDOS ÚTILES POST-DESPLIEGUE
# ═══════════════════════════════════════════════════════════════════════════

# Ver logs en vivo
docker-compose -f docker-compose-prod.yml logs -f backend

# Ver estado
docker-compose -f docker-compose-prod.yml ps

# Reiniciar todo
docker-compose -f docker-compose-prod.yml restart

# Reiniciar solo backend
docker-compose -f docker-compose-prod.yml restart backend

# Detener
docker-compose -f docker-compose-prod.yml down

# Ver uso de recursos
docker stats

# Ejecutar comando en BD
docker-compose -f docker-compose-prod.yml exec mysql mysql -u root -piM5H3WBfwE1VujQk
