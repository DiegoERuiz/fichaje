# 🎯 FICHAJE - DESPLIEGUE COMPLETO EN VPS CON DOCKER COMPOSE

## 📌 RESUMEN EJECUTIVO

**Repositorio**: https://github.com/DiegoERuiz/fichaje.git
**VPS**: 87.106.125.173 (Ubuntu 24.04)
**Dominio**: https://fichajes.biedma.com
**Tecnología**: Docker Compose (MySQL + Spring Boot + Angular + Nginx + Prometheus + Grafana)
**Seguridad**: HTTPS, JWT + Refresh Tokens, Rate Limiting, Auditoría, Contraseñas Fuertes

---

## 🚀 COMENZAR AHORA - 3 FORMAS

### OPCIÓN 1️⃣: AUTOMÁTICA (Recomendada)
```bash
# En tu máquina local
chmod +x deploy-docker-compose.sh
./deploy-docker-compose.sh
```
- ✅ Interfaz interactiva
- ✅ Genera secretos automáticamente
- ✅ Compila backend y frontend
- ✅ Genera SSL
- ✅ Inicia servicios
- ✅ Muestra logs en vivo
- **⏱️ Tiempo**: 15-30 minutos

---

### OPCIÓN 2️⃣: RÁPIDA (5 minutos)
```bash
chmod +x deploy-quick.sh
./deploy-quick.sh
```
- ✅ Script mínimista
- ✅ Automatiza todo lo posible
- ⏱️ **Tiempo**: 10 minutos (compilación automática)

---

### OPCIÓN 3️⃣: MANUAL (Control Total)

Sigue paso a paso en [DESPLIEGUE-DOCKER.md](DESPLIEGUE-DOCKER.md)

---

## 📋 ARCHIVOS PARA DESPLIEGUE

### Scripts de Despliegue
- **`deploy-docker-compose.sh`** - Despliegue completo y guiado (RECOMENDADO)
- **`deploy-quick.sh`** - Despliegue automático rápido
- **`monitor-fichaje.sh`** - Monitoreo post-despliegue
- **`verify-deployment.sh`** - Verificación pre-despliegue

### Configuración Docker
- **`docker-compose-prod.yml`** - Orquestación de servicios
- **`apps/fichaje-be/Dockerfile-prod`** - Imagen backend
- **`deploy/prod/nginx.conf`** - Configuración reverse proxy

### Documentación
- **`DESPLIEGUE-DOCKER.md`** - Guía completa (3 opciones)
- **`QUICK-REFERENCE.md`** - Referencia rápida
- **`DEPLOYMENT_VPS.md`** - Guía manual paso a paso
- **`QUICKSTART-VPS.md`** - Quick start alternativo

---

## ✅ VERIFICACIÓN PRE-DESPLIEGUE

```bash
chmod +x verify-deployment.sh
./verify-deployment.sh
```

Verifica:
- ✅ Archivos de configuración
- ✅ Scripts de despliegue
- ✅ Documentación
- ✅ Herramientas locales (Docker, SSH, etc.)
- ✅ Código fuente
- ✅ Variables de seguridad
- ✅ Conectividad SSH

---

## 🔑 SECRETOS REQUERIDOS

Antes de desplegar, genera:

```bash
# 1. JWT_SECRET (256 caracteres para tokens)
openssl rand -base64 192 | tr -d '\n'

# 2. DB_PASSWORD (contraseña segura para MySQL)
openssl rand -base64 12 | tr -d '=+/'

# 3. SSL_KEYSTORE_PASSWORD (para HTTPS)
openssl rand -base64 12 | tr -d '=+/'

# 4. GRAFANA_PASSWORD (opcional)
openssl rand -base64 12
```

**⚠️ IMPORTANTE**: El script pedirá estos valores durante la ejecución.

---

## 🏗️ ARQUITECTURA DOCKER

```
🐳 Docker Compose
├── 🗄️  MySQL 8.0 (puerto 3306)
│   └── Base de datos db_fichajespi_prod
│
├── ☕ Backend Spring Boot (puerto 8443 - HTTPS)
│   ├── JWT + Refresh Tokens
│   ├── Auditoría de logins
│   ├── Rate Limiting (100 req/min)
│   └── Contraseña fuerte requerida
│
├── 🌐 Nginx Alpine (puertos 80/443)
│   ├── Reverse proxy → Backend
│   ├── Proxy estático → Frontend Angular
│   ├── SSL/TLS (Let's Encrypt)
│   └── Headers de seguridad
│
├── 📦 Redis Alpine (puerto 6379 - opcional)
│   └── Caché en memoria
│
├── 📈 Prometheus (puerto 9090)
│   └── Recopila métricas
│
└── 📊 Grafana (puerto 3000)
    └── Dashboards + alertas

```

---

## 🌐 ACCESO POST-DESPLIEGUE

| Servicio | URL | Usuario | Contraseña |
|----------|-----|---------|-----------|
| **Aplicación** | https://fichajes.biedma.com | - | - |
| **Grafana** | http://87.106.125.173:3000 | admin | admin123 |
| **Prometheus** | http://87.106.125.173:9090 | - | - |
| **API Health** | https://fichajes.biedma.com/actuator/health | - | - |

---

## 🔧 MONITOREO POST-DESPLIEGUE

### Comandos útiles
```bash
chmod +x monitor-fichaje.sh

# Ver estado
./monitor-fichaje.sh status

# Ver logs en vivo
./monitor-fichaje.sh logs

# Verificar salud
./monitor-fichaje.sh health

# Crear backup
./monitor-fichaje.sh backup

# Renovar SSL
./monitor-fichaje.sh ssl-renew
```

### SSH Directo
```bash
ssh root@87.106.125.173
cd /opt/fichaje

# Ver logs
docker-compose -f docker-compose-prod.yml logs -f backend

# Reiniciar
docker-compose -f docker-compose-prod.yml restart

# Ver estado
docker-compose -f docker-compose-prod.yml ps
```

---

## 🔒 CARACTERÍSTICAS DE SEGURIDAD IMPLEMENTADAS

✅ **HTTPS Obligatorio**
- Certificado Let's Encrypt
- HSTS headers (1 año)
- TLS 1.2+

✅ **JWT Tokens**
- Access token: 10 horas
- Refresh token: 7 días
- Rotación automática

✅ **Auditoría**
- Registro de logins (lastLoginAt, lastLoginIp)
- Contador de intentos fallidos
- Bloqueo de cuenta tras 5 intentos

✅ **Validación de Contraseña**
- Mínimo 8 caracteres
- Mayúscula + minúscula + número + especial

✅ **Rate Limiting**
- 100 requests/minuto por IP
- Configururable

✅ **Headers de Seguridad**
- Content-Security-Policy
- X-Frame-Options: SAMEORIGIN
- X-Content-Type-Options: nosniff
- X-XSS-Protection
- Referrer-Policy

---

## 📊 ESTRUCTURA DE DESPLIEGUE

```
/opt/fichaje/          # Raíz de la aplicación
├── .env.prod          # Variables de entorno (NO versionado)
├── docker-compose-prod.yml
├── fichajes-keystore.p12 # Certificado SSL
├── apps/
│   ├── fichaje-be/    # Backend Spring Boot
│   │   ├── target/
│   │   │   └── fichaje-be-1.0.0.jar
│   │   └── Dockerfile-prod
│   ├── fichaje-fe/    # Frontend Angular
│   │   └── dist/      # Build compilado
│   └── ...
├── deploy/
│   └── prod/
│       └── nginx.conf
└── docker/            # Volúmenes
    ├── mysql_data/
    ├── prometheus_data/
    └── grafana_data/
```

---

## 🚨 SOLUCIONAR PROBLEMAS

### Backend no inicia
```bash
ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose -f docker-compose-prod.yml logs backend | tail -50'
```

### Nginx 502 Bad Gateway
```bash
# Verificar backend
ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose -f docker-compose-prod.yml ps backend'
# Esperar 1-2 minutos a que termine de iniciar
```

### BD no conecta
```bash
ssh root@87.106.125.173 'cd /opt/fichaje && docker-compose -f docker-compose-prod.yml exec mysql mysql -u root -e "SHOW DATABASES;"'
```

### Certificado SSL expirado
```bash
ssh root@87.106.125.173 'certbot renew --force-renewal && docker-compose -f docker-compose-prod.yml restart nginx'
```

---

## ✅ CHECKLIST FINAL

Antes de ir a producción:

- [ ] Verificación pre-despliegue pasada (`verify-deployment.sh`)
- [ ] Secretos generados (JWT, DB_PASSWORD, SSL)
- [ ] DNS configurado (fichajes.biedma.com → 87.106.125.173)
- [ ] HTTPS funciona sin warnings
- [ ] Login funciona
- [ ] Refresh token funciona
- [ ] Auditoría registra logins
- [ ] Rate limiting activo
- [ ] Grafana muestra métricas
- [ ] Backups configurados
- [ ] Logs limpios sin errores

---

## 📞 SOPORTE

**Repositorio**: https://github.com/DiegoERuiz/fichaje.git
**Dominio**: https://fichajes.biedma.com
**VPS IP**: 87.106.125.173
**Usuario**: root

---

## 🎓 PRÓXIMAS TAREAS (Opcional)

- [ ] CI/CD con GitHub Actions
- [ ] Backups automáticos en AWS S3
- [ ] Logs centralizados (ELK Stack)
- [ ] Alertas avanzadas
- [ ] Load balancing si hay múltiples instancias
- [ ] Disaster recovery plan

---

## 📄 LICENCIA & CRÉDITOS

Desenvolvimiento: Biedma
Framework: Spring Boot 2.5.1, Angular, Docker
Seguridad: OWASP Top 10

---

**¡Listo para desplegar en producción!** 🚀

```bash
./deploy-docker-compose.sh
```
