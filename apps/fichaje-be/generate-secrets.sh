#!/bin/bash

# Script para generar secretos seguros para producción en Linux/Mac

echo "============================================================"
echo "Generador de Secretos Seguros para Fichaje Producción"
echo "============================================================"
echo ""

# Generar JWT Secret
echo "Generando JWT Secret (256 caracteres aleatorios en base64)..."
JWT_SECRET=$(openssl rand -base64 256)
echo "JWT_SECRET=$JWT_SECRET"
echo ""

# Generar Database Password
echo "Generando Database Password (32 caracteres aleatorios)..."
DB_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-32)
echo "DB_PASSWORD=$DB_PASSWORD"
echo ""

# Generar Keystore Password
echo "Generando Keystore Password (24 caracteres aleatorios)..."
KEYSTORE_PASSWORD=$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-24)
echo "SSL_KEYSTORE_PASSWORD=$KEYSTORE_PASSWORD"
echo ""

echo "============================================================"
echo "Guarda estos valores en variables de entorno seguras"
echo "NO los versionices en git"
echo "============================================================"
echo ""
echo "Para configurar variables de entorno en Linux/Mac:"
echo "  export JWT_SECRET=\"$JWT_SECRET\""
echo "  export DB_PASSWORD=\"$DB_PASSWORD\""
echo "  export SSL_KEYSTORE_PASSWORD=\"$KEYSTORE_PASSWORD\""
echo ""
echo "O en un archivo .env para Docker (NO versionar):"
echo "  JWT_SECRET=$JWT_SECRET"
echo "  DB_PASSWORD=$DB_PASSWORD"
echo "  SSL_KEYSTORE_PASSWORD=$KEYSTORE_PASSWORD"
echo ""

# Crear archivo .env.prod con permisos restringidos (opcional)
echo ""
read -p "¿Crear archivo .env.prod local? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Creando .env.prod con permisos restringidos..."
    cat > .env.prod << EOF
# ADVERTENCIA: No versionar este archivo en git
# Usar variables de entorno en lugar de mantener localmente

JWT_SECRET=$JWT_SECRET
DB_PASSWORD=$DB_PASSWORD
SSL_KEYSTORE_PASSWORD=$KEYSTORE_PASSWORD
DB_URL=jdbc:mysql://your-db-host:3306/db_fichajespi?useSSL=true
DB_USERNAME=fichajes_prod
CLIENT_URL=https://yourdomain.com
SSL_KEYSTORE_PATH=/etc/ssl/fichaje/keystore.p12
SSL_KEY_ALIAS=tomcat
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your_app_password
SPRING_PROFILES_ACTIVE=prod
EOF
    chmod 600 .env.prod
    echo "✓ Archivo .env.prod creado con permisos restringidos (600)"
    echo "  Recuerda agregarlo a .gitignore"
fi
