# 🚀 QUICK START - Despliegue en VPS

## Opción 1: Despliegue Manual (Recomendado para mayor control)

### Paso 1: Conectar al VPS
```bash
ssh root@87.106.125.173
```

### Paso 2: Descargar script de despliegue
```bash
cd /tmp
curl -O https://raw.githubusercontent.com/tu-repo/fichaje/main/deploy-vps.sh
chmod +x deploy-vps.sh
./deploy-vps.sh
```

El script te guiará paso a paso interactivamente.

---

## Opción 2: Despliegue con Docker Compose (Más rápido)

### Paso 1: Crear archivo `.env.prod`
```bash
cat > .env.prod << 'EOF'
# Base de Datos
MYSQL_ROOT_PASSWORD=root-password-segura
DB_NAME=db_fichajespi_prod
DB_USER=fichajes_prod
DB_PASSWORD=password-segura-bd

# JWT (Generar con: openssl rand -base64 192)
JWT_SECRET=tu-jwt-secret-aqui
JWT_EXPIRATION=36000000
JWT_REFRESH_EXPIRATION=604800000

# SSL Keystore
SSL_KEYSTORE_PASSWORD=keystore-password

# URLs
CLIENT_URL=https://fichajes.biedma.com
SERVER_URL=https://fichajes.biedma.com:8443

# Mail
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=tu-email@gmail.com
MAIL_PASSWORD=tu-app-password
MAIL_FROM=noreply@biedma.com

# Rate Limiting
RATE_LIMIT_ENABLED=true

# Grafana
GRAFANA_PASSWORD=admin-password
EOF

chmod 600 .env.prod
```

### Paso 2: Iniciar servicios
```bash
docker-compose -f docker-compose-prod.yml up -d
```

### Paso 3: Ver logs
```bash
docker-compose -f docker-compose-prod.yml logs -f backend
```

---

## Opción 3: Despliegue Manual desde VPS

### En tu máquina local (Windows/Mac/Linux):
```bash
# 1. Compilar aplicación
cd apps/fichaje-be
./mvnw clean package -DskipTests -Dspring.profiles.active=prod

cd ../fichaje-fe
npm install
npm run build -- --prod

# 2. Copiar archivos al VPS
scp -r target/fichaje-be-*.jar root@87.106.125.173:/opt/fichaje/
scp -r apps/fichaje-fe/dist root@87.106.125.173:/opt/fichaje/

# 3. Conectar al VPS
ssh root@87.106.125.173
```

### En el VPS:
```bash
# Crear servicio systemd
sudo tee /etc/systemd/system/fichaje.service > /dev/null << 'EOF'
[Unit]
Description=Fichaje Application
After=network.target mysql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/fichaje
EnvironmentFile=/opt/fichaje/.env.prod

ExecStart=/bin/bash -c 'java -jar fichaje-be-*.jar'
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Iniciar
sudo systemctl daemon-reload
sudo systemctl enable fichaje
sudo systemctl start fichaje

# Ver estado
sudo systemctl status fichaje
```

---

## ✅ Verificación

### 1. Ver que todos los servicios estén activos
```bash
systemctl status fichaje
systemctl status nginx
systemctl status mysql
```

### 2. Probar HTTPS
```bash
curl -k https://fichajes.biedma.com/
```

### 3. Ver logs
```bash
journalctl -u fichaje -f
tail -f /var/log/nginx/error.log
```

### 4. Acceder a la aplicación
```
https://fichajes.biedma.com
```

---

## 🔑 Generar Secrets

### JWT_SECRET (requerir en .env)
```bash
openssl rand -base64 192 | tr -d '\n'
```

### Keystore para SSL
```bash
keytool -genkeypair -alias tomcat \
  -keyalg RSA -keysize 2048 \
  -keystore fichajes-keystore.p12 \
  -storetype PKCS12 \
  -storepass CONTRASEÑA_AQUI \
  -validity 365 \
  -dname "CN=fichajes.biedma.com, O=Biedma, C=ES"
```

### Certificado SSL Let's Encrypt
```bash
certbot certonly --standalone \
  -d fichajes.biedma.com \
  --agree-tos \
  -m admin@biedma.com \
  -n
```

---

## 📊 Endpoints útiles

- **Aplicación**: https://fichajes.biedma.com
- **API**: https://fichajes.biedma.com/api
- **Swagger (dev)**: http://localhost:8080/swagger-ui.html
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000

---

## 🆘 Solucionar problemas

### Aplicación no inicia
```bash
journalctl -u fichaje -n 100
java -jar fichaje-be-*.jar  # Ejecutar manualmente para ver errores
```

### Nginx 502 Bad Gateway
```bash
curl -k https://localhost:8443/actuator/health  # Verificar backend
netstat -tulpn | grep 8443
```

### Base de datos no conecta
```bash
mysql -h localhost -u fichajes_prod -p
SHOW DATABASES;
```

### Certificado SSL expirado
```bash
certbot renew --force-renewal
systemctl reload nginx
```

---

## 📋 Comandos útiles

```bash
# Reiniciar aplicación
systemctl restart fichaje

# Ver espacio en disco
df -h

# Ver uso de CPU/Memoria
top

# Backup de base de datos
mysqldump -u fichajes_prod -p db_fichajespi_prod | gzip > backup.sql.gz

# Restaurar backup
gunzip < backup.sql.gz | mysql -u fichajes_prod -p db_fichajespi_prod

# Ver puertos en escucha
netstat -tulpn | grep LISTEN
```

---

## 🔒 Seguridad

- ✅ Rate limiting habilitado (100 req/min por IP)
- ✅ HTTPS obligatorio
- ✅ JWT tokens con refresh token
- ✅ Contraseñas fuertes requeridas
- ✅ Auditoría de logins habilitada
- ✅ Account lockout tras 5 intentos fallidos
- ✅ HSTS headers configurados
- ✅ CSRF protection activa

---

Para soporte: admin@biedma.com
