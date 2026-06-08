@echo off
REM Script para generar secretos seguros para producción en Windows
REM Requiere PowerShell instalado

echo ============================================================
echo Generador de Secretos Seguros para Fichaje Producción
echo ============================================================
echo.

REM Generar JWT Secret
echo Generando JWT Secret (256 caracteres aleatorios en base64)...
powershell -NoProfile -Command ^
  "^
    $chars = [char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%%^&*()-_=+[]{}|;:,.<>?'; ^
    $random = New-Object System.Random; ^
    $secret = -join (1..256 | ForEach-Object { $chars[$random.Next($chars.Length)] }); ^
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($secret)); ^
    Write-Host \"JWT_SECRET=$encoded\" ^
  "
echo.

REM Generar Database Password
echo Generando Database Password (32 caracteres)...
powershell -NoProfile -Command ^
  "^
    $chars = [char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'; ^
    $random = New-Object System.Random; ^
    $password = -join (1..32 | ForEach-Object { $chars[$random.Next($chars.Length)] }); ^
    Write-Host \"DB_PASSWORD=$password\" ^
  "
echo.

REM Generar Keystore Password
echo Generando Keystore Password (24 caracteres)...
powershell -NoProfile -Command ^
  "^
    $chars = [char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'; ^
    $random = New-Object System.Random; ^
    $password = -join (1..24 | ForEach-Object { $chars[$random.Next($chars.Length)] }); ^
    Write-Host \"SSL_KEYSTORE_PASSWORD=$password\" ^
  "
echo.

echo ============================================================
echo Guarda estos valores en variables de entorno seguras
echo NO los versionices en git
echo ============================================================
echo.
echo Para configurar variables de entorno en Windows:
echo   setx JWT_SECRET "valor_aqui"
echo   setx DB_PASSWORD "valor_aqui"
echo   setx SSL_KEYSTORE_PASSWORD "valor_aqui"
echo.
echo O en un archivo .env para Docker (NO versionar):
echo   JWT_SECRET=valor_aqui
echo   DB_PASSWORD=valor_aqui
echo   SSL_KEYSTORE_PASSWORD=valor_aqui
echo.
