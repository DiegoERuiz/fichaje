#!/bin/bash
# Script de verificación final pre-despliegue
# Valida que todo esté listo antes de ir a producción

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  ✅ VERIFICACIÓN PRE-DESPLIEGUE FICHAJE                  ║"
echo "╚═══════════════════════════════════════════════════════════╝"

CHECKS=0
PASSED=0

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_file() {
    local file=$1
    local name=$2
    CHECKS=$((CHECKS+1))
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $name"
        PASSED=$((PASSED+1))
    else
        echo -e "${RED}✗${NC} $name (falta: $file)"
    fi
}

check_exec() {
    local cmd=$1
    local name=$2
    CHECKS=$((CHECKS+1))
    
    if command -v $cmd &> /dev/null; then
        echo -e "${GREEN}✓${NC} $name"
        PASSED=$((PASSED+1))
    else
        echo -e "${RED}✗${NC} $name (comando: $cmd)"
    fi
}

# ════════════════════════════════════════════════════════════
echo -e "\n${YELLOW}📋 Archivos de Configuración${NC}"
check_file "docker-compose-prod.yml" "docker-compose-prod.yml"
check_file "apps/fichaje-be/Dockerfile-prod" "Dockerfile (Backend)"
check_file "deploy/prod/nginx.conf" "Nginx config"
check_file ".env.prod" ".env.prod (variables)"

# ════════════════════════════════════════════════════════════
echo -e "\n${YELLOW}📝 Scripts de Despliegue${NC}"
check_file "deploy-docker-compose.sh" "Script automático"
check_file "deploy-quick.sh" "Script rápido"
check_file "monitor-fichaje.sh" "Script monitoreo"

# ════════════════════════════════════════════════════════════
echo -e "\n${YELLOW}📚 Documentación${NC}"
check_file "DESPLIEGUE-DOCKER.md" "Guía despliegue"
check_file "QUICK-REFERENCE.md" "Referencia rápida"
check_file "DEPLOYMENT_VPS.md" "Guía manual completa"

# ════════════════════════════════════════════════════════════
echo -e "\n${YELLOW}🔧 Herramientas Locales${NC}"
check_exec "docker" "Docker"
check_exec "docker-compose" "Docker Compose"
check_exec "ssh" "SSH"
check_exec "git" "Git"
check_exec "openssl" "OpenSSL"

# ════════════════════════════════════════════════════════════
echo -e "\n${YELLOW}🏗️  Código Fuente${NC}"
check_file "apps/fichaje-be/pom.xml" "Backend pom.xml"
check_file "apps/fichaje-fe/package.json" "Frontend package.json"
check_file "apps/fichaje-be/target/fichaje-be-1.0.0.jar" "Backend JAR compilado"

# ════════════════════════════════════════════════════════════
echo -e "\n${YELLOW}🔐 Seguridad${NC}"

if [ -f ".env.prod" ]; then
    echo -e "${GREEN}✓${NC} .env.prod existe"
    PASSED=$((PASSED+1))
    CHECKS=$((CHECKS+1))
    
    if grep -q "JWT_SECRET" ".env.prod"; then
        echo -e "${GREEN}✓${NC} JWT_SECRET configurado"
        PASSED=$((PASSED+1))
    else
        echo -e "${RED}✗${NC} JWT_SECRET no configurado"
    fi
    CHECKS=$((CHECKS+1))
    
    if grep -q "DB_PASSWORD" ".env.prod"; then
        echo -e "${GREEN}✓${NC} DB_PASSWORD configurado"
        PASSED=$((PASSED+1))
    else
        echo -e "${RED}✗${NC} DB_PASSWORD no configurado"
    fi
    CHECKS=$((CHECKS+1))
else
    echo -e "${RED}✗${NC} .env.prod no existe"
    CHECKS=$((CHECKS+3))
fi

# ════════════════════════════════════════════════════════════
echo -e "\n${YELLOW}🌐 Red y Conectividad${NC}"

# Verificar SSH
if ssh -o BatchMode=yes -o ConnectTimeout=5 root@87.106.125.173 "echo OK" &> /dev/null; then
    echo -e "${GREEN}✓${NC} SSH a VPS funciona"
    PASSED=$((PASSED+1))
else
    echo -e "${YELLOW}⚠${NC} SSH a VPS no responde (normal si VPS está offline)"
fi
CHECKS=$((CHECKS+1))

# ════════════════════════════════════════════════════════════
echo -e "\n${YELLOW}📊 Compilación${NC}"

if [ -f "apps/fichaje-be/target/fichaje-be-1.0.0.jar" ]; then
    SIZE=$(du -h "apps/fichaje-be/target/fichaje-be-1.0.0.jar" | cut -f1)
    echo -e "${GREEN}✓${NC} Backend compilado ($SIZE)"
    PASSED=$((PASSED+1))
else
    echo -e "${YELLOW}⚠${NC} Backend no compilado (se compilará en VPS)"
fi
CHECKS=$((CHECKS+1))

if [ -d "apps/fichaje-fe/dist" ]; then
    echo -e "${GREEN}✓${NC} Frontend compilado"
    PASSED=$((PASSED+1))
else
    echo -e "${YELLOW}⚠${NC} Frontend no compilado (se compilará en VPS)"
fi
CHECKS=$((CHECKS+1))

# ════════════════════════════════════════════════════════════
echo -e "\n╔═══════════════════════════════════════════════════════════╗"
echo -e "║  📊 RESULTADO FINAL                                       ║"
echo -e "╚═══════════════════════════════════════════════════════════╝"

PERCENTAGE=$((PASSED * 100 / CHECKS))
echo -e "\nVerificaciones: ${GREEN}$PASSED/$CHECKS${NC} pasadas ($PERCENTAGE%)"

if [ $PASSED -eq $CHECKS ]; then
    echo -e "\n${GREEN}✅ ¡LISTO PARA DESPLIEGUE!${NC}"
    echo -e "\nPróximo paso:"
    echo -e "  1. Inicia sesión en VPS: ${YELLOW}ssh root@87.106.125.173${NC}"
    echo -e "  2. Ejecuta: ${YELLOW}./deploy-docker-compose.sh${NC}"
    echo -e "     O: ${YELLOW}./deploy-quick.sh${NC}"
    exit 0
elif [ $PASSED -ge $((CHECKS - 3)) ]; then
    echo -e "\n${YELLOW}⚠️  PARCIALMENTE LISTO${NC}"
    echo -e "\nItems faltantes:"
    echo -e "  - Items marcados con ${RED}✗${NC} deben corregirse"
    echo -e "  - Items marcados con ${YELLOW}⚠${NC} pueden generarse en VPS"
    echo -e "\nContinuar: ${YELLOW}./deploy-docker-compose.sh${NC}"
    exit 1
else
    echo -e "\n${RED}❌ NO LISTO PARA DESPLIEGUE${NC}"
    echo -e "\nCorrige los errores antes de continuar:"
    echo -e "  - Verifica archivos requeridos"
    echo -e "  - Compila el proyecto localmente"
    echo -e "  - Configura .env.prod con secretos"
    exit 2
fi
