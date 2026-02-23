![Fichaje logo](packages/brand/assets/logo.svg)

# Fichaje - Sistema de Registro de Jornada Laboral

[![Monorepo](https://img.shields.io/badge/monorepo-turborepo-6A5ACD)](https://turbo.build/repo)
[![Package Manager](https://img.shields.io/badge/pnpm-%E2%89%A58-blueviolet)](https://pnpm.io/)
[![Frontend](https://img.shields.io/badge/Angular-13-red)](https://angular.io/)
[![Backend](https://img.shields.io/badge/Spring%20Boot-2.5-brightgreen)](https://spring.io/projects/spring-boot)
[![Java](https://img.shields.io/badge/Java-11-orange)](https://adoptium.net/temurin/releases/)
[![Docker](https://img.shields.io/badge/Docker-Compose-informational)](deploy/)
[![CodeQL](https://github.com/jamataran/fichaje/actions/workflows/codeql.yml/badge.svg)](https://github.com/jamataran/fichaje/actions/workflows/codeql.yml)
[![Deployed on Northflank](https://img.shields.io/badge/Deployed%20on-Northflank-0ea5e9)](https://northflank.com)
[![RGPD Compliant](https://img.shields.io/badge/RGPD-Compliant-green)](https://gdpr-info.eu/)
[![RDL 8/2019](https://img.shields.io/badge/RDL%208%2F2019-Spain-yellow)](https://www.boe.es/buscar/act.php?id=BOE-A-2019-5720)

## 📋 Descripción

**Fichaje** es una solución integral de **registro de jornada laboral** diseñada para cumplir la normativa española de control horario (RDL 8/2019). Permite a empresas gestionar de forma centralizada:

- 📊 **Fichajes de entrada/salida** con sello de fecha/hora y auditoría completa
- 👥 **Gestión de usuarios** y perfiles de acceso
- 📅 **Calendarios laborales** personalizables
- 🏖️ **Gestión de vacaciones** y ausencias
- ⚠️ **Registro de incidencias** laborales
- 📈 **Informes y reportes** descargables por empleado
- 🔐 **Acceso del trabajador** a sus propios registros

Todo con una **interfaz web intuitiva**, **backend robusto** en Spring Boot y **base de datos MySQL** con retención de datos.

### 🎯 Casos de uso

- Empresas medianas y grandes que necesitan control de jornada laboral
- Cumplimiento normativo español de registro de horas trabajadas
- Gestión centralizada de horarios y ausencias
- Auditoría y trazabilidad de todos los registros

---

## 🌐 Demo pública

Prueba la aplicación sin instalación:

🔗 **URL Demo**: [https://demo.fichaje.org](https://demo.fichaje.org)

- **Usuario**: `fichajesPi000`
- **Contraseña**: `fichajesPi000`

![Demo Screenshot](packages/brand/assets/demo.png)

---

## 👥 Autores del Fork

Este fork ha sido ideado y mantenido por:

[![Javier Velasco García](https://img.shields.io/badge/LinkedIn-Javier%20Velasco%20García-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/javier-velasco-garc%C3%ADa-32434827b/)
[![José Antonio Matarán](https://img.shields.io/badge/LinkedIn-José%20Antonio%20Matarán-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/jamataran/)

**Repositorio actual**: https://github.com/jamataran/fichaje  
**Repositorio original**: https://github.com/alejandroferrin/fichajespi  
**Wiki del proyecto**: https://github.com/jamataran/fichaje/wiki

---

## 📋 Tabla de contenidos
- [Requisitos](#requisitos)
- [Instalación rápida con Docker Compose](#instalación-rápida-con-docker-compose)
- [Cumplimiento normativo](#-cumplimiento-normativo-español-rdl-82019)
- [Acceso y credenciales](#acceso-y-credenciales)
- [Características de seguridad y auditoría](#-características-de-seguridad-y-auditoría)
- [Desarrollo](#desarrollo)
- [Enlaces útiles](#enlaces-útiles)

## ⚙️ Requisitos
- Docker y Docker Compose (versión 3.9+)
- Máquina con al menos **2 vCPU**, **2 GB RAM** y **10 GB de disco** libres
- Puertos configurables vía variables de entorno:
  - **Aplicación (HTTP)**: 80 (configurable con `APP_PORT`)
  - **Aplicación (HTTPS)**: 443 (configurable con `APP_SSL_PORT`)
  - **BD**: 3306 (configurable con `DB_PORT`)
  - **phpMyAdmin**: 81 (configurable con `PHPMYADMIN_PORT`)

## 🚀 Instalación rápida con Docker Compose

### Opción 1: Con imágenes preconstruidas (recomendado)

1. **Descargar archivo `.env`**:
```bash
curl -o deploy/prod/.env https://raw.githubusercontent.com/jamataran/fichaje/main/deploy/prod/.env.example
# Edita deploy/prod/.env con tus valores (MySQL, JWT, SMTP, etc.)
```

2. **Levantar la aplicación completa**:
```bash
docker compose -f deploy/prod/compose.yaml --env-file deploy/prod/.env up -d
```

3. **Acceder a la aplicación** (un único punto de entrada vía proxy inverso):
   - 🌐 **Aplicación**: `http://localhost` (o `https://tudominio.com` con SSL)
   - 🗄️ **phpMyAdmin**: `http://localhost:${PHPMYADMIN_PORT:-81}`
   - 🗄️ **Base de datos MySQL**: `localhost:${DB_PORT:-3306}`

> 💡 El proxy Caddy enruta automáticamente: las peticiones a `/api/*` van al backend y el resto al frontend. No necesitas configurar nada más.

4. **(Opcional) Habilitar SSL con Let's Encrypt**:
```bash
# En deploy/prod/.env configurar:
ENABLE_SSL=true
DOMAIN=tudominio.com
LETSENCRYPT_EMAIL=admin@tudominio.com
```

#### Archivo Docker Compose completo (`deploy/prod/compose.yaml`)

Si prefieres el archivo completo para copiar y pegar:

```yaml
version: '3.9'

services:
  db:
    container_name: fichaje_db
    image: mysql:8.0
    command: >
      --default-authentication-plugin=mysql_native_password
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
    ports:
      - "${DB_PORT:-3306}:3306"
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      TZ: ${TZ:-Europe/Madrid}
    volumes:
      - db_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-uroot", "-p$$MYSQL_ROOT_PASSWORD"]
      interval: 10s
      timeout: 5s
      retries: 10
    restart: unless-stopped
    networks:
      - fichajes-network

  backend:
    container_name: fichaje_be
    image: ${BACKEND_IMAGE:-ghcr.io/jamataran/fichaje-backend:latest}
    environment:
      TZ: ${TZ:-Europe/Madrid}
      SPRING_DATASOURCE_URL: jdbc:mysql://db:3306/${MYSQL_DATABASE}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Europe/Madrid
      SPRING_DATASOURCE_USERNAME: ${MYSQL_USER}
      SPRING_DATASOURCE_PASSWORD: ${MYSQL_PASSWORD}
      CLIENT_URL: ${CLIENT_URL}
      SPRING_MAIL_HOST: ${SPRING_MAIL_HOST}
      SPRING_MAIL_PORT: ${SPRING_MAIL_PORT}
      SPRING_MAIL_USERNAME: ${SPRING_MAIL_USERNAME}
      SPRING_MAIL_PASSWORD: ${SPRING_MAIL_PASSWORD}
      SPRING_MAIL_PROPERTIES_MAIL_SMTP_AUTH: ${SPRING_MAIL_PROPERTIES_MAIL_SMTP_AUTH}
      SPRING_MAIL_PROPERTIES_MAIL_SMTP_STARTTLS_ENABLE: ${SPRING_MAIL_PROPERTIES_MAIL_SMTP_STARTTLS_ENABLE}
      JWT_SECRET: ${JWT_SECRET}
    expose:
      - "8080"
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - fichajes-network

  frontend:
    container_name: fichaje_fe
    image: ${FRONTEND_IMAGE:-ghcr.io/jamataran/fichaje-frontend:latest}
    expose:
      - "80"
    environment:
      TZ: ${TZ:-Europe/Madrid}
    restart: unless-stopped
    networks:
      - fichajes-network

  proxy:
    container_name: fichaje_proxy
    image: caddy:2-alpine
    ports:
      - "${APP_PORT:-80}:80"
      - "${APP_SSL_PORT:-443}:443"
    environment:
      ENABLE_SSL: ${ENABLE_SSL:-false}
      DOMAIN: ${DOMAIN:-localhost}
      LETSENCRYPT_EMAIL: ${LETSENCRYPT_EMAIL:-}
    command: >
      sh -c '
        if [ "$$ENABLE_SSL" = "true" ]; then
          echo "$$DOMAIN {
            tls $$LETSENCRYPT_EMAIL
            handle_path /api/* {
              reverse_proxy backend:8080
            }
            handle {
              reverse_proxy frontend:80
            }
          }" > /etc/caddy/Caddyfile;
        else
          echo ":80 {
            handle_path /api/* {
              reverse_proxy backend:8080
            }
            handle {
              reverse_proxy frontend:80
            }
          }" > /etc/caddy/Caddyfile;
        fi &&
        caddy run --config /etc/caddy/Caddyfile --adapter caddyfile'
    volumes:
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - frontend
      - backend
    restart: unless-stopped
    networks:
      - fichajes-network

  phpmyadmin:
    container_name: fichaje_dbadmin
    image: phpmyadmin:latest
    ports:
      - "${PHPMYADMIN_PORT:-81}:80"
    environment:
      PMA_ARBITRARY: 1
      PMA_HOST: db
      PMA_USER: ${MYSQL_USER}
      PMA_PASSWORD: ${MYSQL_PASSWORD}
    depends_on:
      - db
    restart: unless-stopped
    networks:
      - fichajes-network

networks:
  fichajes-network:
    name: fichajes-prod-network

volumes:
  db_data:
    name: fichajes_db_prod_data
  caddy_data:
    name: fichajes_caddy_data
  caddy_config:
    name: fichajes_caddy_config
```

> ℹ️ **Nota**: La aplicación usa un **proxy inverso Caddy** que enruta automáticamente `/api/*` al backend y el resto al frontend. Variables configurables en `.env`:
> - `APP_PORT=80` - Puerto HTTP de la aplicación
> - `APP_SSL_PORT=443` - Puerto HTTPS (si SSL está habilitado)
> - `DB_PORT=3306` - Puerto de la base de datos
> - `PHPMYADMIN_PORT=81` - Puerto de phpMyAdmin
>
> **SSL con Let's Encrypt** (opcional):
> - `ENABLE_SSL=true` - Habilitar HTTPS con certificado automático
> - `DOMAIN=tudominio.com` - Dominio para el certificado
> - `LETSENCRYPT_EMAIL=admin@tudominio.com` - Email para Let's Encrypt
>
> **Configuración SMTP** (configurable en `.env`):
> - `SPRING_MAIL_HOST` - Servidor SMTP
> - `SPRING_MAIL_PORT` - Puerto SMTP
> - `SPRING_MAIL_USERNAME` - Usuario de correo
> - `SPRING_MAIL_PASSWORD` - Contraseña de correo
> - `SPRING_MAIL_PROPERTIES_MAIL_SMTP_AUTH=true/false` - Autenticación SMTP
> - `SPRING_MAIL_PROPERTIES_MAIL_SMTP_STARTTLS_ENABLE=true/false` - TLS en SMTP

**Detener la aplicación**:
```bash
docker compose -f deploy/prod/compose.yaml --env-file deploy/prod/.env down
```

**Ver logs en tiempo real**:
```bash
docker compose -f deploy/prod/compose.yaml --env-file deploy/prod/.env logs -f
```

### Opción 2: Construir imágenes localmente

Si prefieres compilar tú mismo:

```bash
# 1. Construir imágenes
docker build -t fichaje-backend:local apps/fichaje-be
docker build -t fichaje-frontend:local apps/fichaje-fe

# 2. Actualizar deploy/prod/.env
export FRONTEND_IMAGE=fichaje-frontend:local
export BACKEND_IMAGE=fichaje-backend:local

# 3. Levantar stack
docker compose -f deploy/prod/compose.yaml --env-file deploy/prod/.env up -d
```

## ✅ Acceso y credenciales

Tras la instalación, la aplicación crea un usuario administrador por defecto:

- **Usuario**: `fichajesPi000`
- **Contraseña**: `fichajesPi000`

⚠️ **IMPORTANTE**: Cambia estas credenciales inmediatamente en tu primer acceso.

## 🛡️ Cumplimiento normativo español - RDL 8/2019

Fichaje está diseñado para **cumplir la normativa española de registro de jornada** establecida por el [Real Decreto-Ley 8/2019](https://www.boe.es/buscar/act.php?id=BOE-A-2019-5720), que obliga a las empresas a llevar un registro detallado de las horas trabajadas.

### Características de cumplimiento:

✅ **Fichajes con sello de fecha/hora**: Cada entrada/salida se registra con timestamp exacto  
✅ **Auditoría y trazabilidad completa**: Registro immutable de todos los eventos  
✅ **Retención ≥4 años**: Almacenamiento persistente de todos los datos  
✅ **Acceso del trabajador**: Los empleados pueden consultar sus propios registros  
✅ **Reportes descargables**: Exportación de informes por empleado  
✅ **Gestión de ausencias**: Control de vacaciones, permisos e incidencias  

### Configuración recomendada para España:

1. **Zona horaria**: Configurar a `Europe/Madrid` (ya por defecto)
2. **Retención de datos**: Mínimo 4 años (configurable en base de datos)
3. **Auditoría**: Activa por defecto en todas las operaciones
4. **Permisos**: Configurar acceso basado en roles (Admin, Supervisor, Empleado)
5. **Reportes**: Descargar informes mensuales/anuales para auditoría

**Nota legal**: Los detalles específicos del cumplimiento normativo dependen de tu asesoría legal. Esta aplicación proporciona las herramientas necesarias para implementar un control de jornada conforme a la normativa.

## 🔐 Características de seguridad y auditoría

- 🔑 **Autenticación JWT**: Token-based segura
- 👤 **Control de acceso por roles**: Admin, Supervisor, Empleado
- 📝 **Auditoría completa**: Quién, qué, cuándo en cada acción
- 🔒 **Contraseñas hasheadas**: Algoritmos seguros (bcrypt)
- 🛡️ **HTTPS recomendado**: Compatible con certificados SSL/TLS
- 📊 **RGPD compliant**: Gestión segura de datos personales

## 👨‍💻 Desarrollo

Si quieres contribuir o desarrollar localmente, consulta **[SETUP.md](SETUP.md)** donde encontrarás:

- Cómo levantar el entorno completo con **un solo comando** usando Turborepo
- Estructura del monorepo (apps, packages, deploy)
- Comandos para desarrollo, tests y builds
- Puertos y servicios disponibles en local

**Inicio rápido para desarrolladores**:

```bash
# 1. Instalar dependencias
pnpm install

# 2. Preparar entorno de desarrollo
cp deploy/dev/.env.example deploy/dev/.env

# 3. Levantar todo (infraestructura + backend + frontend)
pnpm dev:stack
```

Esto arrancará (con puertos configurables vía `deploy/dev/.env`):
- MySQL (puerto `3307` - configurable con `DB_PORT`)
- phpMyAdmin (puerto `8081` - configurable con `PHPMYADMIN_PORT`)
- MailHog SMTP (puerto `1025` - configurable con `MAILHOG_SMTP_PORT`)
- MailHog UI (puerto `8025` - configurable con `MAILHOG_UI_PORT`)
- Backend Spring Boot (puerto `8080`)
- Frontend Angular (puerto `4200`)

## 📚 Enlaces útiles
- 🔗 **[Guía de desarrollo](SETUP.md)** - Estructura del monorepo y comandos Turborepo
- 🐳 **[Orquestación Docker](DOCKER.md)** - Detalles de compose dev/test/prod
- 🔄 **[CI/CD](https://github.com/jamataran/fichaje/wiki/CI-CD)** - Pipeline de integración continua
- 📖 **[Wiki del proyecto](https://github.com/jamataran/fichaje/wiki)** - Documentación completa
- 🌐 **[Demo en línea](https://demo.fichaje.org)** - Prueba la aplicación
- 👶 **[Proyecto original](https://github.com/alejandroferrin/fichajespi)** - Repositorio base
