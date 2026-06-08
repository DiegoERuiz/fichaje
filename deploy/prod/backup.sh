#!/bin/bash
# 🔄 Fichaje - Backup automático de BD
# Script para backups diarios de MySQL
# Uso: Agregar a crontab para ejecutar automáticamente

set -e

# Configuración
BACKUP_DIR="/opt/fichaje/backups"
DB_CONTAINER="fichaje_db"
DB_NAME="db_fichajespi_prod"
MYSQL_USER="root"
BACKUP_RETENTION_DAYS=30
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/fichaje_${TIMESTAMP}.sql.gz"

# Crear directorio de backups si no existe
mkdir -p "$BACKUP_DIR"

echo "🔄 [$(date '+%Y-%m-%d %H:%M:%S')] Iniciando backup de BD..."

# Hacer backup
docker exec "$DB_CONTAINER" mysqldump \
  -u"$MYSQL_USER" \
  -p"$MYSQL_ROOT_PASSWORD" \
  --single-transaction \
  --lock-tables=false \
  "$DB_NAME" | gzip > "$BACKUP_FILE"

echo "✅ Backup creado: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"

# Limpiar backups antiguos
echo "🗑️  Eliminando backups más antiguos que $BACKUP_RETENTION_DAYS días..."
find "$BACKUP_DIR" -name "fichaje_*.sql.gz" -mtime +$BACKUP_RETENTION_DAYS -delete

# Contar backups restantes
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/fichaje_*.sql.gz 2>/dev/null | wc -l)
echo "📊 Backups disponibles: $BACKUP_COUNT"

# Verificar integridad del backup
if gzip -t "$BACKUP_FILE" 2>/dev/null; then
  echo "✅ [$(date '+%Y-%m-%d %H:%M:%S')] Backup completado y verificado correctamente"
else
  echo "❌ [$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Backup corrupto!"
  exit 1
fi

# Resumen
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 RESUMEN DE BACKUP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "BD: $DB_NAME"
echo "Archivo: $(basename $BACKUP_FILE)"
echo "Tamaño: $(du -h "$BACKUP_FILE" | cut -f1)"
echo "Ubicación: $BACKUP_DIR"
echo "Retención: $BACKUP_RETENTION_DAYS días"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
