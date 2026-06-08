# Guía de Configuración de Seguridad para Producción

## Variables de Entorno Requeridas

### 1. Base de Datos
```bash
export DB_URL="jdbc:mysql://your-db-host:3306/db_fichajespi?useSSL=true&serverTimezone=Europe/Madrid"
export DB_USERNAME="your_secure_username"
export DB_PASSWORD="your_very_secure_password"
```

### 2. JWT Secret (CRÍTICO)
Generar un secreto seguro:

**PowerShell (Windows):**
```powershell
$secret = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 256 | % {[char]$_}))))
Write-Host $secret
```

**Linux/Mac:**
```bash
openssl rand -base64 256
```

Luego:
```bash
export JWT_SECRET="your_generated_secret_here"
export JWT_EXPIRATION="36000000"  # 10 horas en milisegundos
```

### 3. CORS Configuration
```bash
export CLIENT_URL="https://yourdomain.com"  # Debe ser HTTPS en producción
```

### 4. SSL/TLS Configuration
```bash
# Ruta del keystore PKCS12
export SSL_KEYSTORE_PATH="/etc/ssl/fichaje/keystore.p12"
export SSL_KEYSTORE_PASSWORD="your_keystore_password"
export SSL_KEY_ALIAS="tomcat"
```

**Crear keystore desde certificado SSL:**
```bash
# Si tienes certificado de Let's Encrypt:
openssl pkcs12 -export \
  -in /etc/letsencrypt/live/yourdomain.com/fullchain.pem \
  -inkey /etc/letsencrypt/live/yourdomain.com/privkey.pem \
  -out keystore.p12 \
  -name tomcat \
  -password pass:your_password
```

### 5. Email Configuration
```bash
export MAIL_HOST="smtp.gmail.com"  # o tu proveedor SMTP
export MAIL_PORT="587"
export MAIL_USERNAME="your_email@gmail.com"
export MAIL_PASSWORD="your_app_password"  # Para Gmail: app-specific password
```

### 6. Rate Limiting
```bash
export RATE_LIMIT_ENABLED="true"
```

### 7. Active Profile
```bash
export SPRING_PROFILES_ACTIVE="prod"
```

---

## Deploying with Docker

### Crear archivo `.env` (NO versionar en git)
```bash
# .env.prod
DB_URL=jdbc:mysql://mysql-container:3306/db_fichajespi?useSSL=true
DB_USERNAME=fichajes_prod
DB_PASSWORD=<very-secure-password>
JWT_SECRET=<base64-encoded-secret>
CLIENT_URL=https://yourdomain.com
SSL_KEYSTORE_PATH=/etc/ssl/keystore.p12
SSL_KEYSTORE_PASSWORD=<password>
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=<app-password>
```

### Ejecutar con Docker Compose
```bash
docker compose --env-file .env.prod -f deploy/prod/compose.yaml up -d
```

---

## Seguridad Implementada

✅ **JWT con secreto seguro**: Tokens firmados con HS512
✅ **HTTPS obligatorio**: Requiere SSL/TLS
✅ **Rate Limiting**: 100 requests/minuto por IP
✅ **CORS restringido**: Solo dominio configurado
✅ **Swagger protegido**: No visible en producción
✅ **Credenciales en variables de entorno**: No hardcodeadas
✅ **SQL preparado**: Protección contra SQL injection
✅ **Validación de entrada**: DTOs validados
✅ **Cookies seguras**: HttpOnly + Secure + SameSite
✅ **Logging de auditoría**: Intentos de auth registrados

---

## Checklist Pre-Producción

- [ ] Generar JWT_SECRET seguro
- [ ] Generar y obtener certificado SSL (Let's Encrypt recomendado)
- [ ] Crear keystore PKCS12 desde certificado
- [ ] Configurar variables de entorno en servidor
- [ ] Base de datos con SSL/TLS habilitado
- [ ] Email SMTP configurado y probado
- [ ] Firewall: Solo HTTPS (443) accesible públicamente
- [ ] Backup automático de BD configurado
- [ ] Monitoring y alertas activados
- [ ] Logs centralizados (opcional pero recomendado)

---

## Monitoreo en Producción

**Endpoints para monitoreo:**
```bash
# Health check
curl https://yourdomain.com:8443/actuator/health

# Métricas
curl https://yourdomain.com:8443/actuator/metrics

# Info de aplicación
curl https://yourdomain.com:8443/actuator/info
```

> ⚠️ Estos actuators deben deshabilitarse en producción si no son necesarios
