# Fichaje Deploy Manual - GUÍA (NO CONTIENE SECRETOS)
# ⚠️ ESTO ES UN EJEMPLO - REEMPLAZA LOS VALORES CON LOS TUYOS
# Ejecuta estos comandos uno por uno en la terminal SSH

# ═══════════════════════════════════════════════════════════════════════════
# 1. CONECTAR A VPS
# ═══════════════════════════════════════════════════════════════════════════
ssh root@TU_IP_VPS

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
git clone https://github.com/TU_USUARIO/fichaje.git fichaje
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
    -d TU_DOMINIO.COM \
    --non-interactive \
    --agree-tos \
    -m TU_EMAIL@example.com

# ═══════════════════════════════════════════════════════════════════════════
# 14. GENERAR KEYSTORE PKCS12 PARA HTTPS
# ═══════════════════════════════════════════════════════════════════════════
cd /opt/fichaje

# REEMPLAZA CON TU SSL_KEYSTORE_PASSWORD GENERADO CON: python -c "import secrets; print(secrets.token_urlsafe(12))"
SSL_KEYSTORE_PASSWORD="<TU_SSL_KEYSTORE_PASSWORD>"

openssl pkcs12 -export \
    -in /etc/letsencrypt/live/TU_DOMINIO.COM/fullchain.pem \
    -inkey /etc/letsencrypt/live/TU_DOMINIO.COM/privkey.pem \
    -out /opt/fichaje/fichajes-keystore.p12 \
    -name fichaje \
    -passout pass:${SSL_KEYSTORE_PASSWORD}

# Verificar que se creó correctamente
ls -lh /opt/fichaje/fichajes-keystore.p12

# ═══════════════════════════════════════════════════════════════════════════
# 15. CREAR .env CON LOS SECRETOS GENERADOS
# ═══════════════════════════════════════════════════════════════════════════
# ⚠️ GENERAR SECRETOS NUEVOS CON:
# python -c "import secrets; print('JWT_SECRET=' + secrets.token_urlsafe(144))"
# python -c "import secrets; print('DB_PASSWORD=' + secrets.token_urlsafe(12))"
# python -c "import secrets; print('MYSQL_ROOT_PASSWORD=' + secrets.token_urlsafe(12))"

cat > /opt/fichaje/.env << 'EOF'
# 🌐 Configuración Fichaje - Producción
# ⚠️ NUNCA SUBIR AL GITHUB

APP_PORT=8080
APP_SSL_PORT=8443
DB_PORT=3306

# SSL
ENABLE_SSL=true
DOMAIN=<TU_DOMINIO.COM>
LETSENCRYPT_EMAIL=<TU_EMAIL@example.com>

# Base de datos (GENERAR NUEVOS SECRETOS)
MYSQL_ROOT_PASSWORD=<GENERAR_CON_SECRETS>
MYSQL_DATABASE=db_fichajespi_prod
MYSQL_USER=fichajes_prod
MYSQL_PASSWORD=<GENERAR_CON_SECRETS>
MYSQL_INITDB_SKIP_TZINFO=yes
TZ=Europe/Madrid

# URLs
IP=<TU_DOMINIO.COM>
CLIENT_URL=https://<TU_DOMINIO.COM>
APP_DOMAIN=<TU_DOMINIO.COM>
APP_URL=https://<TU_DOMINIO.COM>

# JWT (GENERAR CON: python -c "import secrets; print(secrets.token_urlsafe(144))")
JWT_SECRET=<GENERAR_CON_SECRETS>
JWT_EXPIRATION=36000000
JWT_REFRESH_EXPIRATION=604800000

# SSL Keystore (GENERAR CON: python -c "import secrets; print(secrets.token_urlsafe(12))")
SSL_KEYSTORE_PASSWORD=<GENERAR_CON_SECRETS>
SSL_KEYSTORE_ALIAS=fichaje
KEYSTORE_PATH=/opt/fichaje/fichajes-keystore.p12

# Mail (opcional)
SPRING_MAIL_HOST=smtp.gmail.com
SPRING_MAIL_PORT=587
SPRING_MAIL_USERNAME=<TU_EMAIL@gmail.com>
SPRING_MAIL_PASSWORD=<TU_GMAIL_APP_PASSWORD>
SPRING_MAIL_PROPERTIES_MAIL_SMTP_AUTH=true
SPRING_MAIL_PROPERTIES_MAIL_SMTP_STARTTLS_ENABLE=true

# Redis
REDIS_HOST=redis
REDIS_PORT=6379

# Prometheus & Grafana
PROMETHEUS_PORT=9090
GRAFANA_PASSWORD=<GENERAR_CON_SECRETS>
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
# REEMPLAZA <MYSQL_ROOT_PASSWORD> CON TU CONTRASEÑA
docker-compose -f docker-compose-prod.yml exec -T mysql mysql -u root -p<MYSQL_ROOT_PASSWORD> -e "SHOW DATABASES;"

# ═══════════════════════════════════════════════════════════════════════════
# 20. VERIFICAR API BACKEND
# ═══════════════════════════════════════════════════════════════════════════
curl -k https://localhost:8443/actuator/health

# ═══════════════════════════════════════════════════════════════════════════
# ✅ LISTO - ACCESOS
# ═══════════════════════════════════════════════════════════════════════════
# Aplicación:  https://<TU_DOMINIO.COM>
# Grafana:     http://<TU_IP_VPS>:3000 (admin/PASSWORD_GENERADO)
# Prometheus: http://<TU_IP_VPS>:9090
# API Health: https://<TU_DOMINIO.COM>/actuator/health

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
docker-compose -f docker-compose-prod.yml exec mysql mysql -u root -p<MYSQL_ROOT_PASSWORD>
