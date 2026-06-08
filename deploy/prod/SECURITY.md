# 🔐 Guía de Seguridad - Fichaje Producción

## 1. Capas de Seguridad Implementadas

### Nivel 1: Transporte (HTTPS/TLS)
```
✅ Let's Encrypt automático (renovación automática)
✅ HSTS habilitado (max-age: 1 año)
✅ TLS 1.2+ requerido
```

### Nivel 2: Red
```
✅ Firewall OpenStack (puertos 22, 80, 443)
✅ MySQL aislado en red Docker interna
✅ Reverse proxy Caddy aisla servicios internos
```

### Nivel 3: Autenticación
```
✅ PhpMyAdmin: Apache Basic Auth (user/pass)
✅ MySQL: Credenciales en .env (no Git)
✅ JWT: 192+ caracteres (Spring Boot)
```

### Nivel 4: Rate Limiting & DoS
```
✅ 200 req/min por IP en Caddy
✅ Backend con healthchecks
✅ Timeout en proxies (30s)
```

### Nivel 5: Auditoría
```
✅ Logs JSON de todos los accesos
✅ Timestamps y datos de request
✅ Guardados 10 rotaciones (100 MB cada)
```

### Nivel 6: Backup & Recuperación
```
✅ Backups diarios a las 2:00 AM
✅ Compresión gzip + verificación
✅ Retención: 30 días
```

---

## 2. Checklist de Producción

### ✅ Antes de ir a producción

- [ ] Cambiar todas las contraseñas en `.env`
- [ ] Generar nuevo JWT_SECRET (192+ caracteres aleatorios)
- [ ] Cambiar credenciales MySQL (_ROOT_PASSWORD y MYSQL_PASSWORD)
- [ ] Cambiar contraseña Apache en `.htpasswd`
- [ ] Verificar certificado SSL (Let's Encrypt)
- [ ] Configurar email SMTP
- [ ] Instalar backups automáticos (`install-backup-cron.sh`)
- [ ] Verificar logs de Caddy y backend
- [ ] Hacer backup inicial de base de datos
- [ ] Probar restauración de backup
- [ ] Documentar credenciales en gestor de secretos (no en Git)

### ⚠️ Configuraciones por revisar

```bash
# 1. Verificar que .env NO está en Git
git status deploy/prod/.env  # Debe estar ignorado

# 2. Verificar rate limiting
curl -v https://fichajes.biedma.com/api/test

# 3. Verificar headers de seguridad
curl -I https://fichajes.biedma.com/
# Buscar: Strict-Transport-Security, X-Frame-Options, etc.

# 4. Verificar logs
docker exec fichaje_proxy tail -20 /var/log/caddy/access.log
```

---

## 3. Monitoreo en Producción

### Salud de servicios
```bash
# Estado de contenedores
docker ps --format 'table {{.Names}}\t{{.Status}}'

# Logs de cada servicio
docker logs fichaje_db --tail 50
docker logs fichaje_be --tail 50
docker logs fichaje_proxy --tail 50
```

### Alertas a implementar
```
⚠️ CPU > 80%
⚠️ Memoria > 85%
⚠️ Disco < 10%
⚠️ Backup falla
⚠️ SSL cert vence en < 30 días
⚠️ Tasa de errores > 5%
```

---

## 4. Respuesta ante Incidentes

### 🚨 Posible ataque DDoS
```bash
# Verificar logs
docker exec fichaje_proxy grep "denied\|rate limit" /var/log/caddy/access.log

# Ver IPs con más requests
docker exec fichaje_proxy jq -r '.remote' /var/log/caddy/access.log | \
  sort | uniq -c | sort -rn | head -10

# Aumentar rate limiting en Caddyfile si es necesario
# Cambiar: 200 requests per 1m → 100 requests per 1m
```

### 🚨 MySQL lento
```bash
# Ver queries lentas
docker exec fichaje_db mysql -u root -p$MYSQL_ROOT_PASSWORD \
  -e "SELECT * FROM INFORMATION_SCHEMA.PROCESSLIST WHERE TIME > 30;"

# Ver tamaño de BD
docker exec fichaje_db mysql -u root -p$MYSQL_ROOT_PASSWORD \
  -e "SELECT table_name, ROUND(((data_length + index_length) / 1024 / 1024), 2) AS size_mb FROM INFORMATION_SCHEMA.TABLES WHERE table_schema='db_fichajespi_prod' ORDER BY size_mb DESC;"

# Hacer backup urgente
/opt/fichaje/deploy/prod/backup.sh
```

### 🚨 Espacio en disco bajo
```bash
# Verificar espacio
df -h /

# Limpiar logs antiguos
docker system prune --volumes

# Eliminar backups más antiguos manualmente
find /opt/fichaje/backups -name "*.sql.gz" -mtime +15 -delete
```

### 🚨 Certificado SSL por expirar
```bash
# Verificar fecha
openssl s_client -connect fichajes.biedma.com:443 -showcerts 2>/dev/null | \
  grep -A5 "issuer="

# Caddy renueva automático, pero verificar logs
docker logs fichaje_proxy | grep -i "certificate\|tls"
```

### 🚨 Aplicación sin responder
```bash
# Verificar contenedor
docker ps | grep fichaje_be

# Ver logs de error
docker logs fichaje_be --tail 100

# Reiniciar servicio
docker-compose -f /opt/fichaje/deploy/prod/compose.yaml \
  restart fichaje_be

# Hacer backup ANTES de hacer cambios
/opt/fichaje/deploy/prod/backup.sh
```

---

## 5. Gestión de Secretos

### ⚠️ NUNCA HACER
```bash
❌ Agregar .env a Git
❌ Poner contraseñas en código
❌ Compartir .env en Slack/email
❌ Usar contraseña "admin" o "password"
```

### ✅ HACER
```bash
✅ Usar gestor de secretos (1Password, Vault, etc.)
✅ Cambiar credenciales cada 90 días
✅ Rotar SSH keys anualmente
✅ Usar ssh-keys para acceso servidor (no password)
```

### Gestores recomendados
- **1Password** (Recomendado para equipos)
- **Hashicorp Vault** (Recomendado para infraestructura)
- **AWS Secrets Manager** (Si usas AWS)
- **GitLab CI/CD Secrets** (Si usas GitLab)

---

## 6. Actualizaciones y Parches

### Aplicar actualizaciones de seguridad
```bash
# Ver versiones
docker images

# Actualizar imagen base
docker pull caddy:2-alpine
docker pull mysql:8.0
docker pull phpmyadmin:latest

# Reconstruir
docker-compose -f /opt/fichaje/deploy/prod/compose.yaml build --no-cache

# Redeploy
docker-compose -f /opt/fichaje/deploy/prod/compose.yaml up -d
```

### Revisar CVE de dependencias
```bash
# Backend (si es Java)
mvn dependency-check:check

# Frontend (si es Node)
npm audit

# Contenedores
trivy image fichaje_backend:latest
trivy image fichaje_frontend:latest
```

---

## 7. Escalabilidad & Performance

### Métricas a monitorear
```
- Latencia P50, P95, P99
- Errores 4xx vs 5xx
- DB queries/sec
- Conexiones activas
- Uso de memoria por contenedor
```

### Herramientas recomendadas
- **Prometheus** — Colectar métricas
- **Grafana** — Visualizar dashboards
- **ELK Stack** — Centralizar logs
- **Sentry** — Error tracking

---

## 8. Cumplimiento Normativo

### GDPR (EU)
```
✅ Datos en EU (servidor en España)
✅ Encriptación en tránsito (HTTPS)
✅ Política de privacidad (link en footer)
✅ Derecho al olvido (CRUD de datos)
```

### Otros
```
⚠️ PCI DSS (si maneja pagos)
⚠️ Auditorías internas regulares
⚠️ Tests de penetración anuales
```

---

## Contactos de emergencia

```
🔴 Incidente crítico
   → Contactar: [AGREGAR CONTACTO]
   → Chat: [AGREGAR LINK]

📞 Soporte técnico
   → Email: [AGREGAR EMAIL]
   → Teléfono: [AGREGAR TELÉFONO]

📋 Escalada
   → Manager: [AGREGAR NOMBRE]
   → CTO: [AGREGAR NOMBRE]
```

---

**Última actualización**: 2026-06-08  
**Versión**: 1.0  
**Status**: ✅ Producción con protecciones enhancidas
