#!/bin/bash
set -e

echo "=== Configurando autenticación en PhpMyAdmin ==="
echo ""

# Step 1: Generate .htpasswd
echo "1️⃣  Generando archivo .htpasswd..."
apt-get update -qq > /dev/null 2>&1
apt-get install -y -qq apache2-utils > /dev/null 2>&1

htpasswd -bc /opt/fichaje/deploy/prod/.htpasswd biedma "SecureDbAccess#2024!Prod"
chmod 644 /opt/fichaje/deploy/prod/.htpasswd
echo "   ✅ .htpasswd creado con usuario: biedma"

# Step 2: Verify htpasswd
echo ""
echo "2️⃣  Verificando archivo .htpasswd..."
cat /opt/fichaje/deploy/prod/.htpasswd
echo "   ✅ .htpasswd verificado"

# Step 3: Down old containers
echo ""
echo "3️⃣  Deteniendo contenedores antiguos..."
cd /opt/fichaje
docker-compose -f deploy/prod/compose.yaml down 2>&1 | grep -v "is not running" || true
echo "   ✅ Contenedores detenidos"

# Step 4: Start new containers with updated config
echo ""
echo "4️⃣  Iniciando contenedores con nueva configuración..."
docker-compose -f deploy/prod/compose.yaml up -d
sleep 5

# Step 5: Test
echo ""
echo "5️⃣  Probando autenticación..."
echo "   Esperando a que PhpMyAdmin se inicie..."
sleep 3

HTTP_CODE=$(curl -u biedma:SecureDbAccess#2024!Prod http://127.0.0.1/db/ -s -o /dev/null -w '%{http_code}')
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ ¡Autenticación funcionando! (HTTP $HTTP_CODE)"
else
    echo "   ⚠️  Código HTTP: $HTTP_CODE"
    echo "   Verificando logs..."
    docker logs fichaje_dbadmin --tail 20
fi

echo ""
echo "=== Configuración completada ==="
echo ""
echo "Accede a: https://fichajes.biedma.com/db/"
echo "Usuario: biedma"
echo "Contraseña: SecureDbAccess#2024!Prod"
