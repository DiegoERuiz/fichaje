#!/bin/bash
# Script rápido de despliegue Docker Compose
# Para usuarios con prisa: clona, configura y despliega

VPS_IP="87.106.125.173"
DOMAIN="fichajes.biedma.com"

echo "╔═══════════════════════════════════════════════════╗"
echo "║  DESPLIEGUE RÁPIDO FICHAJE VPS                   ║"
echo "╚═══════════════════════════════════════════════════╝"

# 1. Conectar y clonar
echo -e "\n📥 Clonando repositorio..."
ssh root@$VPS_IP << 'EOF'
cd /opt/fichaje 2>/dev/null || mkdir -p /opt/fichaje && cd /opt/fichaje
git clone https://github.com/DiegoERuiz/fichaje.git . 2>/dev/null || git pull
EOF

# 2. Preparar secretos
echo -e "\n🔐 Preparando secretos..."

JWT=$(openssl rand -base64 192 | tr -d '\n')
read -p "Contraseña BD: " DB_PASS
read -sp "Contraseña Keystore: " KS_PASS
echo ""

# 3. Crear .env.prod
echo -e "\n📝 Creando configuración..."
ssh root@$VPS_IP << ENVEOF
cat > /opt/fichaje/.env.prod << 'EOF'
JWT_SECRET=$JWT
DB_PASSWORD=$DB_PASS
SSL_KEYSTORE_PASSWORD=$KS_PASS
MYSQL_ROOT_PASSWORD=root-fichaje-2024
GRAFANA_PASSWORD=admin123
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=tu-email@gmail.com
MAIL_PASSWORD=app-password
MAIL_FROM=noreply@$DOMAIN
CLIENT_URL=https://$DOMAIN
SERVER_URL=https://$DOMAIN:8443
RATE_LIMIT_ENABLED=true
SPRING_PROFILES_ACTIVE=prod
EOF
chmod 600 /opt/fichaje/.env.prod
ENVEOF

# 4. Compilar
echo -e "\n🔨 Compilando (esto tarda ~5 min)..."
ssh root@$VPS_IP << 'EOF'
cd /opt/fichaje
apt-get update && apt-get install -y openjdk-11-jdk nodejs npm > /dev/null 2>&1
cd apps/fichaje-be && chmod +x mvnw && ./mvnw clean package -DskipTests -Dspring.profiles.active=prod > /dev/null 2>&1
cd ../fichaje-fe && npm install > /dev/null 2>&1 && npm run build -- --prod > /dev/null 2>&1
cd /opt/fichaje

# Generar certificado
apt-get install -y certbot > /dev/null 2>&1
certbot certonly --standalone -d $DOMAIN --agree-tos -m admin@$DOMAIN -n 2>/dev/null || true

# Generar keystore
keytool -genkeypair -alias tomcat -keyalg RSA -keysize 2048 \
  -keystore /opt/fichaje/fichajes-keystore.p12 -storetype PKCS12 \
  -storepass $(grep SSL_KEYSTORE_PASSWORD .env.prod | cut -d= -f2) \
  -validity 365 -dname "CN=$DOMAIN, O=Biedma, C=ES" -noprompt 2>/dev/null || true
EOF

# 5. Iniciar Docker
echo -e "\n🐳 Iniciando servicios..."
ssh root@$VPS_IP << 'EOF'
cd /opt/fichaje
apt-get install -y docker.io docker-compose > /dev/null 2>&1
systemctl enable docker && systemctl start docker 2>/dev/null || true
docker-compose -f docker-compose-prod.yml down 2>/dev/null || true
docker-compose -f docker-compose-prod.yml up -d
sleep 15
docker-compose -f docker-compose-prod.yml ps
EOF

echo -e "\n✅ LISTO!"
echo -e "\n🌐 Accede a: https://$DOMAIN"
echo -e "📊 Grafana: http://$VPS_IP:3000 (admin/admin123)"
echo -e "\n📋 Ver logs: ssh root@$VPS_IP 'cd /opt/fichaje && docker-compose -f docker-compose-prod.yml logs -f backend'"
