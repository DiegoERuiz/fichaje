#!/bin/bash
# 🔙 Restaurar backup de BD Fichaje

BACKUP_FILE="${1:-.}"

if [ "$BACKUP_FILE" = "." ] || [ -z "$BACKUP_FILE" ]; then
  echo "❌ Uso: $0 <archivo_backup.sql.gz>"
  echo ""
  echo "📁 Backups disponibles:"
  ls -lh /opt/fichaje/backups/fichaje_*.sql.gz 2>/dev/null || echo "   No hay backups"
  exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "❌ Archivo no encontrado: $BACKUP_FILE"
  exit 1
fi

echo "⚠️  RESTAURARÁ LA BASE DE DATOS DESDE: $BACKUP_FILE"
echo ""
read -p "¿Estás seguro? (escribe 'SI' para confirmar): " confirm

if [ "$confirm" != "SI" ]; then
  echo "❌ Operación cancelada"
  exit 1
fi

echo ""
echo "🔄 Restaurando backup..."

# Descomprimir y restaurar
gunzip -c "$BACKUP_FILE" | docker exec -i fichaje_db mysql \
  -u"root" \
  -p"$MYSQL_ROOT_PASSWORD" \
  db_fichajespi_prod

echo "✅ ¡Backup restaurado exitosamente!"
echo ""
echo "⏰ Fecha del backup: $(stat -c '%y' "$BACKUP_FILE" | cut -d' ' -f1-2)"
echo "📊 Tamaño: $(du -h "$BACKUP_FILE" | cut -f1)"
