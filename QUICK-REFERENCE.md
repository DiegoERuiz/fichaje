# 📌 REFERENCIA RÁPIDA - DESPLIEGUE FICHAJE

## 🚀 COMENZAR AHORA (2 opciones)

### ⚡ OPCIÓN 1: Script Automático (Recomendado)
```bash
chmod +x deploy-docker-compose.sh
./deploy-docker-compose.sh
# Sigue las instrucciones interactivas
```
**Tiempo**: 15-30 minutos
**Control**: Guiado paso a paso

---

### ⚡ OPCIÓN 2: Script Rápido
```bash
chmod +x deploy-quick.sh
./deploy-quick.sh
# Ingresa contraseñas cuando se solicite
```
**Tiempo**: 10 minutos (compilación automática)
**Control**: Mínimo

---

## 📋 PASOS CLAVE

1. **Generar Secretos**
   ```bash
   openssl rand -base64 192 | tr -d '\n'  # JWT_SECRET
   ```

2. **Conectar al VPS**
   ```bash
   ssh root@87.106.125.173
   ```

3. **Clonar y Configurar**
   ```bash
   cd /opt/fichaje
   git clone https://github.com/DiegoERuiz/fichaje.git .
   cat > .env.prod << 'EOF'
   JWT_SECRET=...
   DB_PASSWORD=...
   # ... etc
   EOF
   chmod 600 .env.prod
   ```

4. **Compilar**
   ```bash
   cd apps/fichaje-be && ./mvnw clean package -DskipTests
   cd ../fichaje-fe && npm install && npm run build -- --prod
   cd /opt/fichaje
   ```

5. **Iniciar Docker**
   ```bash
   docker-compose -f docker-compose-prod.yml up -d
   ```

6. **Verificar**
   ```bash
   docker-compose -f docker-compose-prod.yml ps
   curl https://fichajes.biedma.com
   ```

---

## 🌐 ACCESO POST-DESPLIEGUE

| Servicio | URL | Usuario | Contraseña |
|----------|-----|---------|-----------|
| **Aplicación** | https://fichajes.biedma.com | - | - |
| **Grafana** | http://87.106.125.173:3000 | admin | admin123 |
| **Prometheus** | http://87.106.125.173:9090 | - | - |
| **API Docs** | https://fichajes.biedma.com/swagger-ui.html | - | - |

---

## 🔧 COMANDOS ÚTILES

### Monitoreo
```bash
# Descargar script
chmod +x monitor-fichaje.sh

# Ver estado
./monitor-fichaje.sh status

# Ver logs en vivo
./monitor-fichaje.sh logs

# Verificar salud
./monitor-fichaje.sh health

# Crear backup
./monitor-fichaje.sh backup
```

### Mantenimiento
```bash
# Reiniciar backend
./monitor-fichaje.sh restart-backend

# Renovar SSL
./monitor-fichaje.sh ssl-renew

# Actualizar desde Git
./monitor-fichaje.sh update

# Limpiar disco
./monitor-fichaje.sh clean
```

### SSH Directo
```bash
# Conectar
ssh root@87.106.125.173

# Ver logs backend
cd /opt/fichaje
docker-compose -f docker-compose-prod.yml logs -f backend

# Reiniciar
docker-compose -f docker-compose-prod.yml restart

# Detener
docker-compose -f docker-compose-prod.yml down
```

---

## 🔑 SECRETOS REQUERIDOS

Generar ANTES de desplegar:

```bash
# 1. JWT_SECRET (256 caracteres)
openssl rand -base64 192 | tr -d '\n'

# 2. DB_PASSWORD (16+ caracteres)
openssl rand -base64 12 | tr -d '=+/'

# 3. SSL_KEYSTORE_PASSWORD (16+ caracteres)
openssl rand -base64 12 | tr -d '=+/'

# 4. GRAFANA_PASSWORD
echo "admin123"  # O generar otro

# 5. MAIL_PASSWORD (de tu proveedor SMTP)
```

**Guardar en**: `fichaje-secrets.txt` (nunca en Git)

---

## ✅ VERIFICACIÓN

```bash
# 1. Servicios corriendo
docker-compose -f docker-compose-prod.yml ps

# 2. Acceso HTTPS
curl -k https://localhost:8443/actuator/health

# 3. Base de datos
docker-compose -f docker-compose-prod.yml exec mysql mysql -u root -proot-fichaje-2024 -e "SHOW DATABASES;"

# 4. Aplicación
https://fichajes.biedma.com

# 5. Logs limpios
docker-compose -f docker-compose-prod.yml logs backend | grep -i error
```

---

## 🆘 PROBLEMAS COMUNES

| Problema | Solución |
|----------|----------|
| Backend no inicia | `docker-compose logs backend \| tail -50` |
| 502 Bad Gateway | Backend tardando: esperar 1-2 min |
| BD no conecta | Verificar variables en `.env.prod` |
| SSL error | `certbot renew --force-renewal` |
| Certificado no genera | Verificar DNS apunta a IP |

---

## 📊 ESTRUCTURA DOCKER

```
🐳 Docker Compose
├── 🗄️  MySQL (3306) - Base de datos
├── ☕ Backend (8443) - Spring Boot HTTPS
├── 🌐 Nginx (80/443) - Reverse proxy + Frontend
├── 📦 Redis (6379) - Caché (opcional)
├── 📈 Prometheus (9090) - Métricas
└── 📊 Grafana (3000) - Dashboards
```

---

## 🔒 SEGURIDAD

✅ HTTPS obligatorio
✅ JWT + Refresh tokens
✅ Rate limiting 100 req/min
✅ Account lockout 5 intentos
✅ Auditoría de logins
✅ Contraseñas fuertes requeridas
✅ Headers de seguridad

---

## 📞 SOPORTE

- **Repo**: https://github.com/DiegoERuiz/fichaje.git
- **Dominio**: fichajes.biedma.com
- **VPS**: 87.106.125.173
- **Admin**: admin@biedma.com

---

**¡Listo para desplegar!** 🚀
