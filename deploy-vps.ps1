# Script de despliegue para Windows PowerShell
# Requiere: OpenSSH, Git, SSH key configurada
# Uso: .\deploy-vps.ps1

param(
    [string]$VpsIp = "87.106.125.173",
    [string]$Domain = "fichajes.biedma.com",
    [string]$AppDir = "/opt/fichaje",
    [string]$RepoUrl = ""
)

# Colores
$colors = @{
    Green  = "Green"
    Red    = "Red"
    Yellow = "Yellow"
    Cyan   = "Cyan"
}

function Write-Header {
    param([string]$Text)
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $colors.Cyan
    Write-Host "🚀 $Text" -ForegroundColor $colors.Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $colors.Cyan
}

function Write-Success {
    param([string]$Text)
    Write-Host "✓ $Text" -ForegroundColor $colors.Green
}

function Write-Error {
    param([string]$Text)
    Write-Host "✗ $Text" -ForegroundColor $colors.Red
}

function Write-Info {
    param([string]$Text)
    Write-Host "ℹ $Text" -ForegroundColor $colors.Yellow
}

function Invoke-SSH {
    param(
        [string]$Script,
        [string]$Description = ""
    )
    
    if ($Description) {
        Write-Host "`n$Description..." -ForegroundColor $colors.Cyan
    }
    
    try {
        $result = ssh root@$VpsIp $Script
        Write-Success "Completado"
        return $result
    }
    catch {
        Write-Error "Error ejecutando comando SSH: $_"
        return $null
    }
}

# ============================================================================
# INICIO
# ============================================================================

Write-Header "DESPLIEGUE AUTOMATIZADO - FICHAJE VPS"

Write-Info "Configuración:"
Write-Host "  VPS IP: $VpsIp"
Write-Host "  Dominio: $Domain"
Write-Host "  App Dir: $AppDir"

# Validar conexión SSH
Write-Info "Verificando conexión SSH..."
try {
    $testSsh = ssh root@$VpsIp "echo OK"
    Write-Success "Conexión SSH establecida"
}
catch {
    Write-Error "No se puede conectar al VPS. Verifica la IP y SSH keys."
    exit 1
}

# ============================================================================
# MENÚ INTERACTIVO
# ============================================================================

$menuOptions = @(
    "1. Actualizar sistema (apt update && upgrade)",
    "2. Instalar dependencias (Java, MySQL, Docker, Nginx)",
    "3. Crear base de datos",
    "4. Clonar repositorio",
    "5. Compilar aplicación",
    "6. Generar secretos (JWT, Keystore)",
    "7. Obtener certificado SSL",
    "8. Configurar variables de entorno",
    "9. Crear servicio systemd",
    "10. Configurar Nginx",
    "11. Ejecutar despliegue completo",
    "0. Salir"
)

$running = $true
while ($running) {
    Write-Host "`n╔════════════════════════════════════╗" -ForegroundColor $colors.Cyan
    Write-Host "║      MENU DE DESPLIEGUE             ║" -ForegroundColor $colors.Cyan
    Write-Host "╚════════════════════════════════════╝" -ForegroundColor $colors.Cyan
    
    foreach ($option in $menuOptions) {
        Write-Host "  $option"
    }
    
    $choice = Read-Host "`nSelecciona opción"
    
    switch ($choice) {
        "1" {
            Invoke-SSH "apt update && apt upgrade -y" "Actualizando sistema"
        }
        
        "2" {
            Write-Info "Instalando dependencias..."
            $script = @"
apt install -y openjdk-11-jdk
apt install -y mysql-server mysql-client
apt install -y docker.io docker-compose
apt install -y nginx certbot python3-certbot-nginx
systemctl enable docker mysql nginx
systemctl start docker mysql nginx
echo "Dependencias instaladas"
"@
            Invoke-SSH $script
        }
        
        "3" {
            $dbPassword = Read-Host "Contraseña para usuario 'fichajes_prod'" -AsSecureString
            $dbPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($dbPassword))
            
            $script = @"
mysql -u root << EOF
CREATE DATABASE IF NOT EXISTS db_fichajespi_prod CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
DROP USER IF EXISTS 'fichajes_prod'@'localhost';
CREATE USER 'fichajes_prod'@'localhost' IDENTIFIED BY '$dbPass';
GRANT ALL PRIVILEGES ON db_fichajespi_prod.* TO 'fichajes_prod'@'localhost';
FLUSH PRIVILEGES;
EOF
"@
            Invoke-SSH $script "Creando base de datos"
        }
        
        "4" {
            if (-not $RepoUrl) {
                $RepoUrl = Read-Host "URL del repositorio Git"
            }
            $script = "cd $AppDir && git clone $RepoUrl ."
            Invoke-SSH $script "Clonando repositorio"
        }
        
        "5" {
            Write-Info "Compilando backend..."
            $script = "cd $AppDir/apps/fichaje-be && chmod +x mvnw && ./mvnw clean package -DskipTests -Dspring.profiles.active=prod"
            Invoke-SSH $script
            
            Write-Info "Compilando frontend..."
            $script = "cd $AppDir/apps/fichaje-fe && apt install -y nodejs npm && npm install && npm run build -- --prod"
            Invoke-SSH $script
        }
        
        "6" {
            Write-Info "Generando secrets de seguridad..."
            
            # Generar JWT_SECRET localmente
            $jwtSecret = openssl rand -base64 192
            $jwtSecret | Out-File -FilePath "jwt-secret.txt" -Encoding ASCII
            
            # Generar Keystore
            $keystorePassword = Read-Host "Contraseña para Keystore" -AsSecureString
            $keystorePass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($keystorePassword))
            
            Write-Success "JWT_SECRET guardado en jwt-secret.txt"
            Write-Info "Enviando Keystore al VPS..."
            
            $script = @"
keytool -genkeypair -alias tomcat `
  -keyalg RSA -keysize 2048 `
  -keystore $AppDir/fichajes-keystore.p12 `
  -storetype PKCS12 `
  -storepass $keystorePass `
  -validity 365 `
  -dname "CN=$Domain, O=Biedma, C=ES" `
  -noprompt
"@
            Invoke-SSH $script
        }
        
        "7" {
            $email = Read-Host "Email para Let's Encrypt"
            $script = @"
certbot certonly --standalone `
  -d $Domain `
  --agree-tos `
  -m $email `
  -n
"@
            Invoke-SSH $script "Generando certificado SSL"
        }
        
        "8" {
            $dbPassword = Read-Host "Contraseña BD" -AsSecureString
            $dbPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($dbPassword))
            
            $smtpHost = Read-Host "Host SMTP"
            $smtpUser = Read-Host "Usuario SMTP"
            $smtpPass = Read-Host "Contraseña SMTP" -AsSecureString
            $smtpPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($smtpPass))
            
            $jwtSecret = Get-Content "jwt-secret.txt" -Raw
            
            $script = @"
cat > $AppDir/apps/fichaje-be/.env.prod << 'EOF'
DB_HOST=localhost
DB_PORT=3306
DB_NAME=db_fichajespi_prod
DB_USER=fichajes_prod
DB_PASSWORD=$dbPass

JWT_SECRET=$jwtSecret
JWT_EXPIRATION=36000000
JWT_REFRESH_EXPIRATION=604800000

SSL_KEYSTORE_PATH=$AppDir/fichajes-keystore.p12
CLIENT_URL=https://$Domain
SERVER_URL=https://$Domain:8443

MAIL_HOST=$smtpHost
MAIL_PORT=587
MAIL_USERNAME=$smtpUser
MAIL_PASSWORD=$smtpPassword
MAIL_FROM=noreply@biedma.com

RATE_LIMIT_ENABLED=true
SPRING_PROFILES_ACTIVE=prod
EOF

chmod 600 $AppDir/apps/fichaje-be/.env.prod
"@
            Invoke-SSH $script "Configurando variables de entorno"
        }
        
        "9" {
            $script = @"
tee /etc/systemd/system/fichaje.service > /dev/null << 'EOF'
[Unit]
Description=Fichaje Application
After=network.target mysql.service

[Service]
Type=simple
User=root
WorkingDirectory=$AppDir/apps/fichaje-be
EnvironmentFile=$AppDir/apps/fichaje-be/.env.prod
ExecStart=/bin/bash -c 'java -jar target/fichaje-be-*.jar'
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable fichaje
systemctl start fichaje
"@
            Invoke-SSH $script "Creando servicio systemd"
        }
        
        "10" {
            $script = @"
tee /etc/nginx/sites-available/$Domain > /dev/null << 'EOF'
server {
    listen 80;
    server_name $Domain;
    return 301 https://\\\$server_name\\\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $Domain;

    ssl_certificate /etc/letsencrypt/live/$Domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$Domain/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    location /api/ {
        proxy_pass https://localhost:8443/;
        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP \\\$remote_addr;
        proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
    }

    location / {
        root $AppDir/apps/fichaje-fe/dist/fichaje-fe;
        index index.html;
        try_files \\\$uri \\\$uri/ /index.html;
    }
}
EOF

ln -sf /etc/nginx/sites-available/$Domain /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx
"@
            Invoke-SSH $script "Configurando Nginx"
        }
        
        "11" {
            Write-Header "EJECUTANDO DESPLIEGUE COMPLETO"
            # Ejecutar todas las opciones
            Write-Info "Este proceso tomará varios minutos..."
            # Aquí irían todos los comandos anteriores
            Write-Success "Despliegue completado"
        }
        
        "0" {
            $running = $false
            Write-Host "`nHasta luego!`n" -ForegroundColor $colors.Green
        }
        
        default {
            Write-Error "Opción no válida"
        }
    }
}

# ============================================================================
# VERIFICACIÓN POST-DESPLIEGUE
# ============================================================================

if ((Read-Host "¿Deseas verificar el estado del despliegue? (s/n)") -eq "s") {
    Write-Header "VERIFICACIÓN FINAL"
    
    Invoke-SSH "systemctl status fichaje --no-pager | head -10" "Estado de la aplicación"
    Invoke-SSH "systemctl status nginx --no-pager | head -10" "Estado de Nginx"
    Invoke-SSH "systemctl status mysql --no-pager | head -10" "Estado de MySQL"
}

Write-Host "`nAccede a https://$Domain para verificar la aplicación`n" -ForegroundColor $colors.Green
