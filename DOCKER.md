# 🐳 Docker Compose - Entornos

Este monorepo utiliza diferentes archivos de Docker Compose para cada entorno.

## 📁 Estructura

```
/
├── docker-compose.yml           # Producción (optimizado, imágenes compiladas)
├── docker-compose.dev.yml       # Desarrollo local (BD, MailHog, PHPMyAdmin)
├── .env.example                 # Variables para producción
├── .env.dev.example             # Variables para desarrollo
└── apps/
    └── fichaje-be/
        └── docker-compose.test.yml  # BD para tests del backend
```

## 🚀 Uso

### Desarrollo Local

**1. Levantar infraestructura de desarrollo (BD + PHPMyAdmin + MailHog):**
```bash
pnpm docker:dev:up
# o desde apps/fichaje-be:
pnpm db:dev:up
```

**2. Ejecutar backend en modo desarrollo:**
```bash
cd apps/fichaje-be
pnpm dev
# El backend se conecta a la BD en localhost:3307
```

**3. Ejecutar frontend en modo desarrollo:**
```bash
cd apps/fichaje-fe
pnpm dev
```

**Servicios disponibles:**
- Backend: http://localhost:8080
- Frontend: http://localhost:4200
- PHPMyAdmin: http://localhost:8081
- MailHog UI: http://localhost:8025 (captura de emails)
- MySQL Dev: localhost:3307

**Parar infraestructura:**
```bash
pnpm docker:dev:down
```

---

### Tests del Backend

**Ejecutar tests con BD temporal:**
```bash
cd apps/fichaje-be
pnpm test:with-db
# Levanta BD en puerto 3308, ejecuta tests y limpia
```

**Levantar solo BD de test (para debug):**
```bash
cd apps/fichaje-be
pnpm db:test:up
pnpm test
pnpm db:test:down
```

---

### Producción

**1. Configurar variables de entorno:**
```bash
cp .env.example .env
# Edita .env con valores de producción
```

**2. Levantar stack completo (BD + Backend + Frontend):**
```bash
pnpm docker:prod:up
```

**3. Ver logs:**
```bash
pnpm docker:prod:logs
```

**4. Parar:**
```bash
pnpm docker:prod:down
```

**Servicios disponibles:**
- Aplicación: http://localhost (proxy Caddy → frontend + backend)
- phpMyAdmin: http://localhost:81
- MySQL Prod: localhost:3306

> 💡 El proxy Caddy enruta `/api/*` al backend y el resto al frontend. Opcionalmente, habilita SSL con `ENABLE_SSL=true`.

---

## 🔧 Configuración de Profiles en Spring Boot

El backend utiliza diferentes profiles:

- **dev** → `application-dev.properties` (BD en puerto 3307, logs debug)
- **test** → `application-test.properties` (BD en puerto 3308, schema recreado)
- **prod** → `application.properties` (valores desde variables de entorno)

---

## 📊 Puertos

| Servicio | Desarrollo | Test | Producción |
|----------|-----------|------|------------|
| Proxy (Caddy) | - | - | 80 / 443 |
| MySQL | 3307 | 3308 | 3306 |
| Backend | 8080 | 8080 | interno (via proxy) |
| Frontend | 4200 | - | interno (via proxy) |
| PHPMyAdmin | 8081 | - | 81 |
| MailHog SMTP | 1025 | - | - |
| MailHog UI | 8025 | - | - |

---

## 💡 Tips

- **Desarrollo:** No necesitas levantar backend/frontend en Docker, solo la infraestructura (BD, MailHog)
- **Tests:** La BD se levanta en tmpfs (memoria RAM) para mayor velocidad
- **Producción:** Las imágenes se construyen con multi-stage build optimizado
- **MailHog:** En desarrollo captura todos los emails sin enviarlos realmente

