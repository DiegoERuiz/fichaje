#!/bin/bash
set -e

echo "=== Redeployando PhpMyAdmin con Autenticación Apache ==="
echo ""

cd /opt/fichaje

# Stop old containers
echo "1️⃣  Deteniendo contenedores..."
docker-compose -f deploy/prod/compose.yaml down 2>&1 | grep -v "is not running" || true
echo "   ✅ Detenidos"

# Build and start
echo ""
echo "2️⃣  Construyendo imagen personalizada de PhpMyAdmin..."
docker-compose -f deploy/prod/compose.yaml build phpmyadmin --no-cache
echo "   ✅ Imagen construida"

echo ""
echo "3️⃣  Iniciando contenedores..."
docker-compose -f deploy/prod/compose.yaml up -d
sleep 10

# Check status
echo ""
echo "4️⃣  Estado de contenedores..."
docker ps --format "table {{.Names}}\t{{.Status}}"

# Test authentication
echo ""
echo "5️⃣  Probando autenticación..."
echo "   Esperando PhpMyAdmin..."
sleep 3

echo ""
echo "   a) Sin credenciales (debe ser rechazado 401):"
curl -s http://127.0.0.1/db/ -o /dev/null -w "   Status: %{http_code}\n"

echo "   b) Con credenciales correctas (debe ser 200):"
curl -s -u biedma:SecureDbAccess#2024!Prod http://127.0.0.1/db/ -o /dev/null -w "   Status: %{http_code}\n"

echo "   c) Con credenciales incorrectas (debe ser 401):"
curl -s -u biedma:wrongpassword http://127.0.0.1/db/ -o /dev/null -w "   Status: %{http_code}\n"

echo ""
echo "=== Redeploy completado ==="
echo ""
echo "🎉 Accede a: https://fichajes.biedma.com/db/"
echo "   Usuario: biedma"
echo "   Contraseña: SecureDbAccess#2024!Prod"
