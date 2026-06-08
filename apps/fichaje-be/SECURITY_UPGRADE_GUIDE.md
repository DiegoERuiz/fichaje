# Guía de Actualización de Seguridad - Fichaje Backend

## ✅ Cambios Implementados

### 1. **Dependencias Agregadas**
- ✅ `bucket4j-core` para rate limiting
- ✅ `spring-boot-configuration-processor` para propiedades de configuración

### 2. **Configuración Segura**
- ✅ `application-prod.properties` - Configuración de producción con SSL/TLS
- ✅ Variables de entorno para secretos
- ✅ Support de HTTPS obligatorio
- ✅ Cookies seguras (HttpOnly, Secure, SameSite)

### 3. **Seguridad en Endpoints**
- ✅ Proteger `/fichaje/now` - Ahora requiere autenticación USER
- ✅ Swagger protegido en producción - No visible sin autenticación
- ✅ HTTPS obligatorio - Requiere canal seguro

### 4. **Rate Limiting**
- ✅ `RateLimitingFilter` - Limita 100 requests/minuto por IP
- ✅ `RateLimitProperties` - Propiedades configurables
- ✅ `RateLimitConfig` - Registración del filtro

### 5. **Scripts de Utilidad**
- ✅ `generate-secrets.sh` - Generar secretos seguros (Linux/Mac)
- ✅ `generate-secrets.bat` - Generar secretos seguros (Windows)
- ✅ `SECURITY_PRODUCTION.md` - Guía detallada de configuración

---

## 🚀 Pasos para Activar en Producción

### Paso 1: Generar Secretos Seguros

**En Windows (PowerShell):**
```powershell
# Navega a la carpeta del proyecto
cd apps\fichaje-be
.\generate-secrets.bat
```

**En Linux/Mac:**
```bash
cd apps/fichaje-be
chmod +x generate-secrets.sh
./generate-secrets.sh
```

### Paso 2: Obtener Certificado SSL

Si usas Let's Encrypt:
```bash
# Instalar certbot
sudo apt-get install certbot python3-certbot-nginx

# Generar certificado
sudo certbot certonly --standalone -d yourdomain.com

# Crear keystore PKCS12 desde el certificado
openssl pkcs12 -export \
  -in /etc/letsencrypt/live/yourdomain.com/fullchain.pem \
  -inkey /etc/letsencrypt/live/yourdomain.com/privkey.pem \
  -out keystore.p12 \
  -name tomcat \
  -password pass:YOUR_KEYSTORE_PASSWORD
```

### Paso 3: Configurar Variables de Entorno

En tu servidor de producción:

```bash
# Base de datos
export DB_URL="jdbc:mysql://db-host:3306/db_fichajespi?useSSL=true"
export DB_USERNAME="fichajes_prod"
export DB_PASSWORD="<generated-password>"

# JWT
export JWT_SECRET="<generated-secret>"
export JWT_EXPIRATION="36000000"

# CORS
export CLIENT_URL="https://yourdomain.com"

# SSL
export SSL_KEYSTORE_PATH="/etc/ssl/fichaje/keystore.p12"
export SSL_KEYSTORE_PASSWORD="<keystore-password>"
export SSL_KEY_ALIAS="tomcat"

# Email
export MAIL_HOST="smtp.gmail.com"
export MAIL_PORT="587"
export MAIL_USERNAME="your-email@gmail.com"
export MAIL_PASSWORD="<app-password>"

# Active profile
export SPRING_PROFILES_ACTIVE="prod"
```

### Paso 4: Compilar y Desplegar

```bash
# Compilar
mvn clean package -DskipTests -P prod

# Ejecutar con variables de entorno
java -jar target/fichaje-be-0.0.1-SNAPSHOT.jar
```

### Paso 5: Verificar Que Funciona

```bash
# Check HTTPS (debe funcionar)
curl -k https://yourdomain.com:8443/auth/login

# Check que HTTP redirija a HTTPS (o falle)
curl -i http://yourdomain.com:8080/auth/login
# Debe responder error o redirección

# Check rate limiting
for i in {1..101}; do curl -s https://yourdomain.com:8443/auth/login > /dev/null; done
# El request 101+ debe responder 429 (Too Many Requests)
```

---

## 📋 Cambios en Código

### MainSecurity.java
```java
// NUEVO: Swagger protegido en producción
if ("prod".equalsIgnoreCase(profile)) {
    web.ignoring().antMatchers("/webjars/**");
} else {
    // En dev: permite acceso sin autenticación
}

// NUEVO: HTTPS obligatorio
http.requiresChannel()
    .anyRequest()
    .requiresSecure()

// ACTUALIZADO: /fichaje/now ahora requiere autenticación
.antMatchers("/fichaje/now").hasRole(USER)  // Antes: .permitAll()
```

### application.properties
```properties
# Ahora soporta variables de entorno
client.url=${CLIENT_URL:http://localhost:4200}
jwt.secret=${JWT_SECRET:very-secure-secret}
rate-limit.enabled=${RATE_LIMIT_ENABLED:true}
```

### Rate Limiting Implementado
- Máximo: 100 requests/minuto por IP
- Responde 429 (Too Many Requests) cuando se supera
- Incluye header `X-Rate-Limit-Retry-After-Seconds`

---

## 🔐 Checklist de Seguridad

- [ ] Certificado SSL obtenido
- [ ] Keystore PKCS12 creado
- [ ] JWT_SECRET generado y configurado
- [ ] DB_PASSWORD generado y configurado
- [ ] MAIL configurado con app-password (si usas Gmail)
- [ ] CLIENT_URL establecida a dominio HTTPS
- [ ] Variables de entorno configuradas en servidor
- [ ] Probado: HTTPS funciona (puerto 8443)
- [ ] Probado: Swagger no es públicamente accesible
- [ ] Probado: /fichaje/now requiere autenticación
- [ ] Probado: Rate limiting funciona
- [ ] Base de datos hace backups automáticos
- [ ] Logs centralizados configurados
- [ ] Monitoring/alertas activos

---

## ⚠️ Importante

**NO VERSIONES EN GIT:**
- `.env.prod`
- `keystore.p12`
- Archivos con secretos

**Usa .gitignore:**
```
.env*
*.p12
generate-secrets.sh
generate-secrets.bat
```

---

## 📚 Documentación Completa

Ver [SECURITY_PRODUCTION.md](./SECURITY_PRODUCTION.md) para:
- Variables de entorno detalladas
- Instrucciones de SSL/TLS
- Configuración de Docker
- Monitoreo en producción
- Troubleshooting

---

## 🆘 Troubleshooting

**Error: "No se puede acceder a HTTPS"**
- Verificar que el keystore existe en SSL_KEYSTORE_PATH
- Verificar contraseña del keystore
- Revisar logs de Spring Boot

**Error: "Rate limit no funciona"**
- Verificar RATE_LIMIT_ENABLED=true
- Revisar proxy/load balancer (podría cambiar IP)

**Error: "JWT_SECRET no se carga"**
- Verificar variable de entorno: `echo $JWT_SECRET`
- Verificar que no haya comillas extras

**Error: "CORS bloqueado"**
- Verificar CLIENT_URL coincide con dominio del frontend
- Debe ser HTTPS en producción
