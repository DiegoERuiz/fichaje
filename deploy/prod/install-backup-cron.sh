#!/bin/bash
# 🔧 Instalación de backup automático en crontab

BACKUP_SCRIPT="/opt/fichaje/deploy/prod/backup.sh"

echo "📦 Instalando backup automático..."

# Hacer ejecutable
chmod +x "$BACKUP_SCRIPT"

# Crear entrada en crontab (diariamente a las 2 AM)
# Primero, removemos si ya existe
(crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT" || true) | crontab -

# Agregar nuevo cron job
(crontab -l 2>/dev/null || echo "") | cat - <(echo "# Fichaje backup diario - 2 AM") <(echo "0 2 * * * /bin/bash $BACKUP_SCRIPT >> /var/log/fichaje-backup.log 2>&1") | crontab -

echo "✅ Cron job instalado:"
echo "   Ejecutar: 0 2 * * * $BACKUP_SCRIPT"
echo ""
echo "📋 Próxima ejecución:"
next_run=$(date -d "tomorrow 02:00" 2>/dev/null || date -v+1d -f "%Y-%m-%d 02:00" 2>/dev/null)
echo "   $next_run"
echo ""
echo "📝 Ver logs en: /var/log/fichaje-backup.log"
echo "💾 Backups guardados en: /opt/fichaje/backups/"
