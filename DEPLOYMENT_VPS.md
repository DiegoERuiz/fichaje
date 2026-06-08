# 🚀 Guía de Despliegue Fichaje en VPS Ubuntu 24.04

## 📋 Datos del VPS
- **IP**: 87.106.125.173
- **Usuario**: root
- **OS**: Ubuntu 24.04
- **Dominio**: https://fichajes.biedma.com/
- **DNS**: Apunta a 87.106.125.173

---

## 1️⃣ PREPARACIÓN DEL VPS (SSH como root)

### Paso 1: Actualizar sistema
```bash
ssh root@87.106.125.173
apt update && apt upgrade -y
apt install -y curl wget git build-essential
```

### Paso 2: Instalar Java 11
```bash
apt install -y openjdk-11-jdk
java -version
```

### Paso 3: Instalar MySQL 8
```bash
apt install -y mysql-server mysql-client
mysql_secure_installation
```

Responder a las preguntas (cambiar root password, remover usuarios anónimos, etc.)

### Paso 4: Instalar Docker y Docker Compose
```bash
apt install -y docker.io docker-compose
usermod -aG docker root
systemctl enable docker
systemctl start docker
```

### Paso 5: Instalar Nginx
```bash
apt install -y nginx certbot python3-certbot-nginx
systemctl enable nginx
systemctl start nginx
```

---

## 2️⃣ CREAR BASE DE DATOS EN MYSQL

### Conectar a MySQL
```bash
mysql -u root -p
```

### Crear BD y usuario
```sql
CREATE DATABASE db_fichajespi_prod CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER 'fichajes_prod'@'localhost' IDENTIFIED BY 'CAMBIAR_CONTRASEÑA_SEGURA';
GRANT ALL PRIVILEGES ON db_fichajespi_prod.* TO 'fichajes_prod'@'localhost';
FLUSH PRIVILEGES;

EXIT;
```

---

## 3️⃣ CLONAR Y COMPILAR APLICACIÓN

### Paso 1: Clonar repositorio
```bash
cd /opt
git clone <URL-DEL-REPOSITORIO> fichaje
cd fichaje
```

### Paso 2: Compilar backend
```bash
cd apps/fichaje-be
chmod +x mvnw
./mvnw clean package -DskipTests -Dspring.profiles.active=prod
```

Esto genera: `target/fichaje-be-X.X.X.jar`

### Paso 3: Compilar frontend (Angular)
```bash
cd ../fichaje-fe
npm install
npm run build -- --prod
```

Esto genera: `dist/fichaje-fe/`

---

## 4️⃣ GENERAR SECRETS Y CERTIFICADOS SSL

### Paso 1: Generar JWT Secret (256 caracteres)
```bash
openssl rand -base64 192 | tr -d '\n'
# Copiar el resultado
```

### Paso 2: Generar Keystore para HTTPS
```bash
keytool -genkeypair -alias tomcat \
  -keyalg RSA -keysize 2048 \
  -keystore /opt/fichaje/fichaje-keystore.p12 \
  -storetype PKCS12 \
  -storepass CAMBIAR_KEYSTORE_PASSWORD \
  -validity 365 \
  -dname "CN=fichajes.biedma.com, O=Biedma, C=ES"
```

### Paso 3: Obtener certificado SSL con Let's Encrypt
```bash
certbot certonly --standalone \
  -d fichajes.biedma.com \
  --agree-tos \
  -m admin@biedma.com \
  -n
```

---

## 5️⃣ CONFIGURAR VARIABLES DE ENTORNO

### Crear archivo `.env.prod` en `/opt/fichaje/apps/fichaje-be/`
```bash
cat > /opt/fichaje/apps/fichaje-be/.env.prod << 'EOF'
# Base de Datos
DB_HOST=localhost
DB_PORT=3306
DB_NAME=db_fichajespi_prod
DB_USER=fichajes_prod
DB_PASSWORD=CONTRASEÑA_SEGURA_BD

# JWT (CRÍTICO: generar con openssl rand -base64 192)
JWT_SECRET=PEGAR_AQUI_EL_RESULTADO_DEL_OPENSSL
JWT_EXPIRATION=36000000
JWT_REFRESH_EXPIRATION=604800000

# HTTPS/SSL
SSL_KEYSTORE_PATH=/opt/fichaje/fichajes-keystore.p12
SSL_KEYSTORE_PASSWORD=CAMBIAR_KEYSTORE_PASSWORD

# URLs
CLIENT_URL=https://fichajes.biedma.com
SERVER_URL=https://fichajes.biedma.com:8443

# Mail (configurar según tu servidor SMTP)
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=tu-email@gmail.com
MAIL_PASSWORD=tu-app-password
MAIL_FROM=noreply@biedma.com

# Rate Limiting
RATE_LIMIT_ENABLED=true

# Perfil Spring
SPRING_PROFILES_ACTIVE=prod
EOF

chmod 600 /opt/fichaje/apps/fichaje-be/.env.prod
```

---

## 6️⃣ CREAR SERVICIO SYSTEMD PARA LA APLICACIÓN

### Crear archivo `/etc/systemd/system/fichaje.service`
```bash
sudo tee /etc/systemd/system/fichaje.service > /dev/null << 'EOF'
[Unit]
Description=Fichaje Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/fichaje/apps/fichaje-be
EnvironmentFile=/opt/fichaje/apps/fichaje-be/.env.prod

ExecStart=/opt/fichaje/apps/fichaje-be/target/fichaje-be-1.0.0.jar

Restart=on-failure
RestartSec=10

# Límites de recursos
MemoryLimit=2G
CPUQuota=80%

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable fichaje
systemctl start fichaje
systemctl status fichaje
```

---

## 7️⃣ CONFIGURAR NGINX COMO REVERSE PROXY

### Crear archivo `/etc/nginx/sites-available/fichajes.biedma.com`
```bash
sudo tee /etc/nginx/sites-available/fichajes.biedma.com > /dev/null << 'EOF'
server {
    listen 80;
    server_name fichajes.biedma.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name fichajes.biedma.com;

    # Certificados SSL de Let's Encrypt
    ssl_certificate /etc/letsencrypt/live/fichajes.biedma.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/fichajes.biedma.com/privkey.pem;

    # Configuración SSL segura
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Headers de seguridad
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css text/xml text/javascript 
               application/x-javascript application/xml+rss 
               application/javascript application/json;

    # Backend Java (puerto 8443)
    location /api/ {
        proxy_pass https://localhost:8443/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 600s;
    }

    # Frontend Angular
    location / {
        root /opt/fichaje/apps/fichaje-fe/dist/fichaje-fe;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    # Archivos estáticos
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
```

### Habilitar sitio y verificar
```bash
ln -s /etc/nginx/sites-available/fichajes.biedma.com /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

nginx -t
systemctl restart nginx
```

---

## 8️⃣ RENOVACIÓN AUTOMÁTICA DE CERTIFICADOS SSL

```bash
# Crear script de renovación
cat > /usr/local/bin/renew-ssl.sh << 'EOF'
#!/bin/bash
certbot renew --quiet
systemctl reload nginx
EOF

chmod +x /usr/local/bin/renew-ssl.sh

# Agregar a crontab para renovar cada mes
echo "0 2 1 * * /usr/local/bin/renew-ssl.sh" | crontab -
```

---

## 9️⃣ VERIFICACIÓN Y PRUEBAS

### Verificar que los servicios están activos
```bash
systemctl status fichaje
systemctl status nginx
systemctl status mysql
```

### Pruebas de conectividad
```bash
# Test HTTPS
curl -k https://fichajes.biedma.com/api/auth/login -X POST \
  -H "Content-Type: application/json" \
  -d '{"numero":"test","password":"test"}'

# Ver logs de la aplicación
journalctl -u fichaje -f

# Ver logs de Nginx
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

### Verificar puertos abiertos
```bash
netstat -tulpn | grep LISTEN
# Debe mostrar: 80 (Nginx), 443 (Nginx), 8443 (Fichaje), 3306 (MySQL)
```

---

## 🔟 MONITOREO Y MANTENIMIENTO

### Crear script de backup automático
```bash
cat > /usr/local/bin/backup-fichaje.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup BD
mysqldump -u fichajes_prod -p<PASSWORD> db_fichajespi_prod | gzip > $BACKUP_DIR/db_$DATE.sql.gz

# Rotación (mantener últimos 30 días)
find $BACKUP_DIR -name "db_*.sql.gz" -mtime +30 -delete
EOF

chmod +x /usr/local/bin/backup-fichaje.sh

# Programar diario
echo "0 3 * * * /usr/local/bin/backup-fichaje.sh" | crontab -
```

### Monitoreo de recursos
```bash
# Ver uso de CPU y memoria
top
ps aux | grep fichaje

# Ver espacios en disco
df -h
```

---

## ⚠️ CHECKLIST PRE-PRODUCCIÓN

- [ ] BD creada y accesible
- [ ] Variables de entorno configuradas (especialmente JWT_SECRET)
- [ ] Certificado SSL generado y válido
- [ ] Nginx proxy configurado y funcionando
- [ ] Servicios systemd creados y activos
- [ ] Firewall permitiendo puertos 80, 443
- [ ] Backups automáticos configurados
- [ ] Logs monitoreados y rotados
- [ ] Dominio DNS resolviendo correctamente a 87.106.125.173
- [ ] HTTPS funcionando sin warnings
- [ ] Rate limiting habilitado
- [ ] JWT refresh token funcionando

---

## 🆘 SOLUCIÓN DE PROBLEMAS

### Aplicación no inicia
```bash
journalctl -u fichaje -n 100 --no-pager
```

### Nginx retorna 502 Bad Gateway
```bash
curl localhost:8443  # Verificar si backend está activo
tail -f /var/log/nginx/error.log
```

### Certificado SSL expirado
```bash
certbot renew --force-renewal
systemctl reload nginx
```

### Puertos en uso
```bash
lsof -i :8443
lsof -i :3306
lsof -i :80
```

---

## 📞 CONTACTO Y SOPORTE

Para issues de despliegue contactar a: `admin@biedma.com`
