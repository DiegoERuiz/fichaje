# 📦 Deployment Producción - Fichaje

## Archivos necesarios en este directorio

### 📋 Archivos de configuración (versionados en Git)
- **`compose.yaml`** — Orquestación Docker de 5 servicios
- **`Dockerfile.phpmyadmin`** — Imagen personalizada con Apache Auth
- **`apache-auth.conf`** — Configuración de autenticación básica Apache
- **`.env.example`** — Plantilla con variables necesarias
- **`Caddyfile`** — Configuración de reverse proxy SSL/TLS
- **`nginx.conf`** — Configuración legacy (NO EN USO)

### 🔐 Archivos sensibles (🚫 NO en Git)
- **`.env`** — Credenciales y secretos (Generarlocalmente)
- **`.htpasswd`** — Contraseña Apache para PhpMyAdmin (Generar localmente)

## 🚀 Setup inicial

### 1️⃣ Preparar variables de entorno
```bash
cp .env.example .env
# Editar .env y cambiar todas las contraseñas por valores seguros
```

### 2️⃣ Generar credenciales de Apache
```bash
# Linux/Mac
htpasswd -bc .htpasswd biedma "SecureDbAccess#2024!Prod"

# Windows (si tienes Apache instalado)
# O generar hash online y copiar manualmente
```

### 3️⃣ Desplegar servicios
```bash
docker-compose -f deploy/prod/compose.yaml --env-file deploy/prod/.env up -d
```

### 4️⃣ Verificar servicios
```bash
docker ps --format 'table {{.Names}}\t{{.Status}}'
```

## 📊 Servicios desplegados

| Servicio | Puerto | Protocolo | Acceso |
|----------|--------|-----------|--------|
| **Frontend** | 80 | HTTP | Internal |
| **Backend** | 8080 | HTTP | Internal |
| **MySQL** | 3306 | TCP | Internal |
| **Caddy Proxy** | 80, 443 | HTTP/HTTPS | External |
| **PhpMyAdmin** | 80 | HTTP | Internal `/db` |

## 🔐 Acceso a servicios

### Frontend
- URL: `https://fichajes.biedma.com`
- Acceso: Público

### Backend API
- URL: `https://fichajes.biedma.com/api/`
- Acceso: Desde frontend

### PhpMyAdmin (Administración BD)
- URL: `https://fichajes.biedma.com/db/`
- Usuario (Web): `biedma`
- Contraseña (Web): `SecureDbAccess#2024!Prod` (Apache Auth)
- Usuario (MySQL): `fichajes_prod`
- Contraseña (MySQL): Desde `.env` MYSQL_PASSWORD
- Acceso: **Doble autenticación** (Apache + MySQL config)

## 🔧 Operaciones comunes

### Reiniciar servicios
```bash
docker-compose -f deploy/prod/compose.yaml restart
```

### Ver logs
```bash
# Todos los servicios
docker-compose -f deploy/prod/compose.yaml logs -f

# Servicio específico
docker logs fichaje_dbadmin -f
```

### Actualizar imagen de PhpMyAdmin
```bash
docker-compose -f deploy/prod/compose.yaml build phpmyadmin --no-cache
docker-compose -f deploy/prod/compose.yaml up -d phpmyadmin
```

### Cambiar contraseña Apache
```bash
# Actualizar .htpasswd
htpasswd -bc .htpasswd biedma "nueva_contraseña"

# Copiar al servidor
docker cp .htpasswd fichaje_dbadmin:/etc/apache2/.htpasswd

# Recargar Apache
docker exec fichaje_dbadmin apache2ctl graceful
```

## ⚠️ Security Notes

✅ **HTTPS** — Let's Encrypt automático (Caddy)  
✅ **Basic Auth** — PhpMyAdmin protegido por Apache  
✅ **Credenciales** — Almacenadas solo en `.env` (no en Git)  
✅ **BD Interna** — MySQL accesible solo desde Docker  
✅ **Reverse Proxy** — Caddy aisla acceso directo a servicios  

## 📝 Cambios en `.gitignore`

Estos archivos están excluidos del repositorio:
```
deploy/prod/.env           # Credenciales
deploy/prod/.htpasswd      # Contraseña Apache
deploy/prod/*.log          # Logs
```

## 🆘 Troubleshooting

### PhpMyAdmin no conecta a MySQL
```bash
# Ver logs del contenedor
docker logs fichaje_dbadmin

# Verificar conexión de red
docker exec fichaje_dbadmin nc -zv db 3306
```

### Puerto 443 no responde
```bash
# Verificar Caddy
docker logs fichaje_proxy

# Recargar Caddyfile
docker exec fichaje_proxy caddy reload
```

### Regenerar .htpasswd
```bash
# Opción 1: Comando local
htpasswd -c .htpasswd biedma

# Opción 2: Copiar al servidor y reiniciar
scp .htpasswd root@SERVER:/opt/fichaje/deploy/prod/
ssh root@SERVER "docker-compose -f /opt/fichaje/deploy/prod/compose.yaml restart phpmyadmin"
```

---

**Última actualización**: 2026-06-08  
**Status**: ✅ Producción - Todos los servicios operativos
