# Fichaje Deploy Final
$VpsIp = "87.106.125.173"
$VpsUser = "root"
$VpsHost = "$VpsUser@$VpsIp"
$AppDir = "/opt/fichaje"

Write-Host "Fichaje - Final Deployment" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create .env
Write-Host "[1/3] Creating .env file..." -ForegroundColor Yellow
$env1 = "APP_PORT=8080`r`nAPP_SSL_PORT=8443`r`nDB_PORT=3306`r`nENABLE_SSL=true`r`nDOMAIN=fichajes.biedma.com"
$env2 = "LETSENCRYPT_EMAIL=admin@fichajes.biedma.com`r`nMYSQL_ROOT_PASSWORD=iM5H3WBfwE1VujQk`r`nMYSQL_DATABASE=db_fichajespi_prod"
$env3 = "MYSQL_USER=fichajes_prod`r`nMYSQL_PASSWORD=BKLy0KAk4LUXrHBU`r`nTZ=Europe/Madrid`r`nIP=fichajes.biedma.com"
$env4 = "CLIENT_URL=https://fichajes.biedma.com`r`nSPRING_MAIL_HOST=localhost`r`nSPRING_MAIL_PORT=1025"
$env5 = "SPRING_MAIL_USERNAME=noreply@fichajes.biedma.com`r`nSPRING_MAIL_PASSWORD=dummy`r`nJWT_SECRET=RzQBHEY6ySjY20MbnJZRSo3Gqf9BW4TkGUAROdMktlUbbV44LykPaow5nj1FdmBFrxO9fBIBV9oB4Bcq9r0PUmLNCVMHI-a25r0wlLpXBl3svYlxwVprJWQXjodELw4R9Ln-Tv9xtob2taddty2VRNuglo8sscJpJF5iD8F15ubT3pdy9UwXxJzgGiR3Dblh"
$env6 = "JWT_REFRESH_EXPIRATION=604800000`r`nSSL_KEYSTORE_PASSWORD=gkZJWOo3fP-SaiMM"

ssh $VpsHost "echo -e '$env1' > $AppDir/deploy/prod/.env"
ssh $VpsHost "echo -e '$env2' >> $AppDir/deploy/prod/.env"
ssh $VpsHost "echo -e '$env3' >> $AppDir/deploy/prod/.env"
ssh $VpsHost "echo -e '$env4' >> $AppDir/deploy/prod/.env"
ssh $VpsHost "echo -e '$env5' >> $AppDir/deploy/prod/.env"
ssh $VpsHost "echo -e '$env6' >> $AppDir/deploy/prod/.env"

Write-Host "[+] .env created" -ForegroundColor Green
Write-Host ""

# Step 2: Start Docker
Write-Host "[2/3] Starting Docker services..." -ForegroundColor Yellow
ssh $VpsHost "cd $AppDir; docker-compose -f deploy/prod/compose.yaml up -d" 2>&1 | Out-Null
Start-Sleep -Seconds 30
Write-Host "[+] Services started" -ForegroundColor Green
Write-Host ""

# Step 3: Verify
Write-Host "[3/3] Verifying deployment..." -ForegroundColor Yellow
ssh $VpsHost "cd $AppDir; docker-compose -f deploy/prod/compose.yaml ps" 2>&1
Write-Host ""
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "Access: https://fichajes.biedma.com" -ForegroundColor Cyan
