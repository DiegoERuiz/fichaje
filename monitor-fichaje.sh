#!/bin/bash
# Monitor y mantenimiento de Fichaje en VPS
# Uso: ./monitor-fichaje.sh [start|stop|restart|logs|status|backup]

VPS_IP="87.106.125.173"
DOMAIN="fichajes.biedma.com"
APP_DIR="/opt/fichaje"

command=${1:-status}

case $command in
    status)
        echo "📊 ESTADO DE SERVICIOS"
        ssh root@$VPS_IP << 'EOF'
cd /opt/fichaje
echo "=== Docker Compose ==="
docker-compose -f docker-compose-prod.yml ps

echo -e "\n=== Uso de Recursos ==="
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
EOF
        ;;

    logs)
        echo "📋 LOGS BACKEND (Ctrl+C para salir)"
        ssh root@$VPS_IP << 'EOF'
cd /opt/fichaje
docker-compose -f docker-compose-prod.yml logs -f backend --tail=100
EOF
        ;;

    logs-nginx)
        echo "📋 LOGS NGINX (Ctrl+C para salir)"
        ssh root@$VPS_IP << 'EOF'
cd /opt/fichaje
docker-compose -f docker-compose-prod.yml logs -f nginx --tail=50
EOF
        ;;

    logs-mysql)
        echo "📋 LOGS MYSQL (Ctrl+C para salir)"
        ssh root@$VPS_IP << 'EOF'
cd /opt/fichaje
docker-compose -f docker-compose-prod.yml logs -f mysql --tail=50
EOF
        ;;

    restart)
        echo "🔄 Reiniciando todos los servicios..."
        ssh root@$VPS_IP << 'EOF'
cd /opt/fichaje
docker-compose -f docker-compose-prod.yml restart
sleep 10
docker-compose -f docker-compose-prod.yml ps
EOF
        ;;

    restart-backend)
        echo "🔄 Reiniciando backend..."
        ssh root@$VPS_IP << 'EOF'
cd /opt/fichaje
docker-compose -f docker-compose-prod.yml restart backend
sleep 15
docker-compose -f docker-compose-prod.yml ps backend
EOF
        ;;

    stop)
        echo "⏸️  Deteniendo servicios..."
        ssh root@$VPS_IP << 'EOF'
cd /opt/fichaje
docker-compose -f docker-compose-prod.yml down
echo "✓ Servicios detenidos"
EOF
        ;;

    start)
        echo "▶️  Iniciando servicios..."
        ssh root@$VPS_IP << 'EOF'
cd /opt/fichaje
docker-compose -f docker-compose-prod.yml up -d
sleep 10
docker-compose -f docker-compose-prod.yml ps
EOF
        ;;

    backup)
        echo "💾 Creando backup de BD..."
        BACKUP_FILE="fichaje-backup-$(date +%Y%m%d-%H%M%S).sql.gz"
        ssh root@$VPS_IP << EOF
cd /opt/fichaje
docker-compose -f docker-compose-prod.yml exec -T mysql mysqldump \\
  -u root \\
  -p\$(grep MYSQL_ROOT_PASSWORD .env.prod | cut -d= -f2) \\
  db_fichajespi_prod | gzip > $BACKUP_FILE

echo "✓ Backup guardado: $BACKUP_FILE"
EOF
        # Descargar backup
        scp root@$VPS_IP:/opt/fichaje/$BACKUP_FILE ./
        echo "✓ Backup descargado: $BACKUP_FILE"
        ;;

    health)
        echo "🏥 VERIFICACIÓN DE SALUD"
        ssh root@$VPS_IP << 'EOF'
echo "MySQL:"
docker-compose -f docker-compose-prod.yml exec -T mysql mysqladmin ping -u root -proot-fichaje-2024 2>/dev/null && echo "✓ OK" || echo "✗ ERROR"

echo "Backend:"
curl -k -s https://localhost:8443/actuator/health 2>/dev/null | jq '.status' && echo "✓ OK" || echo "✗ ERROR"

echo "Nginx:"
curl -s http://localhost/health 2>/dev/null | grep -q "healthy" && echo "✓ OK" || echo "✗ ERROR"

echo "Redis:"
docker-compose -f docker-compose-prod.yml exec -T redis redis-cli ping 2>/dev/null && echo "✓ OK" || echo "✗ ERROR"

echo "Prometheus:"
curl -s http://localhost:9090/-/healthy > /dev/null 2>&1 && echo "✓ OK" || echo "✗ ERROR"

echo "Grafana:"
curl -s http://localhost:3000/api/health | jq '.database' && echo "✓ OK" || echo "✗ ERROR"
EOF
        ;;

    ssl-renew)
        echo "🔐 Renovando certificado SSL..."
        ssh root@$VPS_IP << 'EOF'
certbot renew --force-renewal
docker-compose -f docker-compose-prod.yml restart nginx
echo "✓ SSL renovado"
EOF
        ;;

    disk)
        echo "💾 USO DE DISCO"
        ssh root@$VPS_IP << 'EOF'
echo "=== Espacio en disco ==="
df -h | grep -E "^/dev|^Filesystem"

echo -e "\n=== Volúmenes Docker ==="
docker volume ls

echo -e "\n=== Tamaño de volúmenes ==="
docker system df
EOF
        ;;

    db-exec)
        echo "🗄️  ACCESO A BASE DE DATOS"
        read -p "Comando SQL: " sql_cmd
        ssh root@$VPS_IP << EOF
cd /opt/fichaje
docker-compose -f docker-compose-prod.yml exec -T mysql mysql \\
  -u fichajes_prod \\
  -p\$(grep 'DB_PASSWORD=' .env.prod | cut -d= -f2) \\
  db_fichajespi_prod \\
  -e "$sql_cmd"
EOF
        ;;

    update)
        echo "🔄 Actualizando aplicación desde Git..."
        ssh root@$VPS_IP << 'EOF'
cd /opt/fichaje
git pull origin main
docker-compose -f docker-compose-prod.yml down
docker-compose -f docker-compose-prod.yml build --no-cache
docker-compose -f docker-compose-prod.yml up -d
sleep 15
docker-compose -f docker-compose-prod.yml ps
EOF
        ;;

    clean)
        echo "🧹 Limpiando espacios en disco..."
        ssh root@$VPS_IP << 'EOF'
echo "Deteniendo servicios..."
cd /opt/fichaje
docker-compose -f docker-compose-prod.yml down

echo "Limpiando Docker..."
docker system prune -af

echo "Reiniciando..."
docker-compose -f docker-compose-prod.yml up -d
sleep 10
docker-compose -f docker-compose-prod.yml ps
EOF
        ;;

    *)
        cat << 'HELP'
🔧 MONITOR Y MANTENIMIENTO FICHAJE

Uso: ./monitor-fichaje.sh [comando]

COMANDOS:
  status         - Ver estado de servicios (por defecto)
  logs           - Ver logs del backend en vivo
  logs-nginx     - Ver logs de Nginx
  logs-mysql     - Ver logs de MySQL
  health         - Verificar salud de todos los servicios
  
  start          - Iniciar servicios
  stop           - Detener servicios
  restart        - Reiniciar todos los servicios
  restart-backend - Reiniciar solo backend
  
  backup         - Crear backup de BD y descargar
  db-exec        - Ejecutar comando SQL en BD
  
  ssl-renew      - Renovar certificado SSL
  update         - Actualizar desde Git y compilar
  clean          - Limpiar espacios en disco
  disk           - Ver uso de disco

EJEMPLOS:
  ./monitor-fichaje.sh logs           # Ver logs backend
  ./monitor-fichaje.sh health         # Verificar salud
  ./monitor-fichaje.sh backup         # Crear backup
  ./monitor-fichaje.sh restart        # Reiniciar todo
HELP
        ;;
esac
