# 🚀 DESPLIEGUE COMPLETO FICHAJE EN VPS CON DOCKER COMPOSE

## Requisitos Previos

- ✅ Servidor VPS Ubuntu 24.04
- ✅ IP: 87.106.125.173
- ✅ Dominio: https://fichajes.biedma.com/
- ✅ DNS apuntando a la IP
- ✅ SSH acceso root
- ✅ Git instalado localmente

---

## 🎯 OPCIÓN 1: DESPLIEGUE COMPLETO (Recomendado)

### Paso 1: Descargar script
```bash
chmod +x deploy-docker-compose.sh
```

### Paso 2: Ejecutar despliegue
```bash
./deploy-docker-compose.sh
```

El script hará:
- ✅ Actualizar VPS
- ✅ Clonar repositorio
- ✅ Generar secretos de seguridad
- ✅ Compilar backend Java (5-10 min)
- ✅ Compilar frontend Angular
- ✅ Generar certificado SSL
- ✅ Crear keystore
- ✅ Iniciar todos los servicios con Docker Compose
- ✅ Mostrar logs en vivo

---

## ⚡ OPCIÓN 2: DESPLIEGUE RÁPIDO (5 minutos)

### Paso 1: Ejecutar script rápido
```bash
chmod +x deploy-quick.sh
./deploy-quick.sh
```

### Paso 2: Esperar 10 minutos a que compile

---

## 🔧 OPCIÓN 3: DESPLIEGUE MANUAL

### Paso 1: Conectar al VPS
```bash
ssh root@87.106.125.173
cd /opt/fichaje
```

### Paso 2: Clonar repositorio
```bash
git clone https://github.com/DiegoERuiz/fichaje.git .
```

### Paso 3: Crear archivo .env.prod
```bash
cat > .env.prod << 'EOF'
# Base de Datos
MYSQL_ROOT_PASSWORD=root-fichaje-2024
DB_NAME=db_fichajespi_prod
DB_USER=fichajes_prod
DB_PASSWORD=CAMBIAR-ESTO-SEGURO

# JWT
JWT_SECRET=GENERAR-CON-openssl-rand-base64-192
JWT_EXPIRATION=36000000
JWT_REFRESH_EXPIRATION=604800000

# SSL
SSL_KEYSTORE_PATH=/app/fichajes-keystore.p12
SSL_KEYSTORE_PASSWORD=CAMBIAR-ESTO

# URLs
CLIENT_URL=https://fichajes.biedma.com
SERVER_URL=https://fichajes.biedma.com:8443

# Mail
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=tu-email@gmail.com
MAIL_PASSWORD=app-password
MAIL_FROM=noreply@fichajes.biedma.com

# Otros
RATE_LIMIT_ENABLED=true
SPRING_PROFILES_ACTIVE=prod
GRAFANA_PASSWORD=admin123
EOF

chmod 600 .env.prod
```

### Paso 4: Instalar dependencias
```bash
apt-get update
apt-get install -y openjdk-11-jdk nodejs npm docker.io docker-compose certbot keytool
systemctl enable docker
systemctl start docker
```

### Paso 5: Compilar aplicación
```bash
# Backend
cd apps/fichaje-be
chmod +x mvnw
./mvnw clean package -DskipTests -Dspring.profiles.active=prod

# Frontend
cd ../fichaje-fe
npm install
npm run build -- --prod

# Volver a root
cd /opt/fichaje
```

### Paso 6: Generar certificado SSL
```bash
certbot certonly --standalone \
  -d fichajes.biedma.com \
  --agree-tos \
  -m admin@biedma.com \
  -n
```

### Paso 7: Generar Keystore
```bash
KEYSTORE_PASS=$(grep SSL_KEYSTORE_PASSWORD .env.prod | cut -d= -f2)

keytool -genkeypair -alias tomcat \
  -keyalg RSA -keysize 2048 \
  -keystore fichajes-keystore.p12 \
  -storetype PKCS12 \
  -storepass $KEYSTORE_PASS \
  -validity 365 \
  -dname "CN=fichajes.biedma.com, O=Biedma, C=ES" \
  -noprompt
```

### Paso 8: Iniciar Docker Compose
```bash
docker-compose -f docker-compose-prod.yml up -d
```

### Paso 9: Ver estado
```bash
docker-compose -f docker-compose-prod.yml ps
docker-compose -f docker-compose-prod.yml logs -f backend
```

---

## 📋 VERIFICACIÓN

### Servicios activos
```bash
docker-compose -f docker-compose-prod.yml ps
```

Debe mostrar:
```
fichaje-mysql      (healthy)
fichaje-backend    (healthy)
fichaje-nginx      (healthy)
fichaje-redis      (healthy)
fichaje-prometheus (running)
fichaje-grafana    (running)
```

### Pruebas de conectividad
```bash
# Probar HTTPS del backend
curl -k https://localhost:8443/actuator/health

# Probar frontend
curl http://localhost/health

# Probar aplicación completa
curl https://fichajes.biedma.com/
```

### Acceder a la aplicación
```
🌐 Aplicación: https://fichajes.biedma.com
📊 Grafana: http://87.106.125.173:3000 (admin/admin123)
📈 Prometheus: http://87.106.125.173:9090
```

---

## 🔑 SECRETOS GENERADOS

### Generar JWT_SECRET
```bash
openssl rand -base64 192 | tr -d '\n'
```

### Ver secretos en VPS
```bash
grep -v "^#" .env.prod | grep -v "^$"
```

### Guardar secretos localmente (IMPORTANTE)
```bash
scp root@87.106.125.173:/opt/fichaje/.env.prod ./fichaje-secrets-backup.env
chmod 600 ./fichaje-secrets-backup.env
# GUARDAR EN LUGAR SEGURO - NO VERSIONEAR EN GIT
```

---

## 📊 COMANDOS ÚTILES

### Ver logs en vivo
```bash
ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose -f docker-compose-prod.yml logs -f backend'
```

### Reiniciar servicios
```bash
ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose -f docker-compose-prod.yml restart'
```

### Reiniciar solo backend
```bash
ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose -f docker-compose-prod.yml restart backend'
```

### Ver uso de recursos
```bash
ssh root@87.106.125.173 'docker stats'
```

### Limpiar espacios en disco
```bash
ssh root@87.106.125.173 'docker system prune -a'
```

### Backup de BD
```bash
ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose -f docker-compose-prod.yml exec mysql mysqldump -u root -proot-fichaje-2024 db_fichajespi_prod' | gzip > backup.sql.gz
```

### Restaurar BD
```bash
gunzip < backup.sql.gz | ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose -f docker-compose-prod.yml exec -T mysql mysql -u root -proot-fichaje-2024 db_fichajespi_prod'
```

---

## 🆘 SOLUCIONAR PROBLEMAS

### Backend no inicia
```bash
ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose -f docker-compose-prod.yml logs backend | tail -50'
```

### Nginx 502 Bad Gateway
```bash
# Verificar que backend está corriendo
ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose -f docker-compose-prod.yml ps backend'

# Verificar logs de backend
ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose -f docker-compose-prod.yml logs backend | tail -20'
```

### BD no conecta
```bash
ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose -f docker-compose-prod.yml exec mysql mysql -u root -proot-fichaje-2024 -e "SHOW DATABASES;"'
```

### Puerto 8443 en uso
```bash
ssh root@87.106.125.173 'netstat -tulpn | grep 8443'
ssh root@87.106.125.173 'docker-compose -f docker-compose-prod.yml down && sleep 5 && docker-compose -f docker-compose-prod.yml up -d'
```

### Certificado SSL expirado
```bash
ssh root@87.106.125.173 'certbot renew --force-renewal'
ssh root@87.106.125.173 'docker-compose -f docker-compose-prod.yml restart nginx'
```

---

## 🔒 SEGURIDAD

✅ **Implementado:**
- HTTPS obligatorio
- JWT tokens con refresh
- Auditoría de logins
- Rate limiting (100 req/min)
- Contraseñas fuertes requeridas
- Account lockout (5 intentos)
- HSTS headers
- CSP headers

✅ **Base de datos:**
- Usuario dedicado (fichajes_prod)
- Contraseña compleja
- Sin acceso público

✅ **Backend:**
- Spring Security configurado
- CORS restringido
- Headers de seguridad
- Proxy reverse con Nginx

---

## 📞 SOPORTE

**Repo:** https://github.com/DiegoERuiz/fichaje.git
**Dominio:** fichajes.biedma.com
**Admin:** admin@biedma.com

---

## ✅ CHECKLIST POST-DESPLIEGUE

- [ ] HTTPS funciona: https://fichajes.biedma.com/
- [ ] Login funciona
- [ ] Refresh token funciona
- [ ] Auditoría registra logins
- [ ] Rate limiting activo
- [ ] BD conecta
- [ ] Certificado SSL válido
- [ ] Logs limpios sin errores
- [ ] Grafana muestra métricas
- [ ] Backups configurados
- [ ] DNS resuelve correctamente
- [ ] Secretos guardados en lugar seguro

---

**¡Listo para producción!** 🚀
