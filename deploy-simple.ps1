# Fichaje Deploy - Simple PowerShell wrapper
# This transfers the script and executes it on VPS

$VpsIp = "87.106.125.173"
$VpsUser = "root"
$VpsHost = "$VpsUser@$VpsIp"
$ScriptPath = "deploy-direct.sh"
$RemotePath = "/tmp/deploy-fichaje.sh"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FICHAJE DEPLOYMENT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test SSH
Write-Host "[*] Testing SSH connection..." -ForegroundColor Yellow
$testResult = ssh -o ConnectTimeout=5 $VpsHost "echo OK" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Cannot connect to $VpsHost" -ForegroundColor Red
    Write-Host "Make sure you can connect with: ssh root@87.106.125.173" -ForegroundColor Yellow
    exit 1
}

Write-Host "[+] SSH connection OK" -ForegroundColor Green
Write-Host ""

# Transfer script
Write-Host "[*] Transferring deployment script..." -ForegroundColor Yellow
scp $ScriptPath "$($VpsHost):$RemotePath" 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to transfer script" -ForegroundColor Red
    exit 1
}

Write-Host "[+] Script transferred" -ForegroundColor Green
Write-Host ""

# Execute script
Write-Host "[*] Executing deployment on VPS (this will take 20-30 minutes)..." -ForegroundColor Yellow
Write-Host "    Compiling backend and frontend..." -ForegroundColor Gray
Write-Host ""

ssh $VpsHost "bash $RemotePath"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[ERROR] Deployment failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "DEPLOYMENT COMPLETED SUCCESSFULLY!" -ForegroundColor Green  
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Access URLs:" -ForegroundColor Cyan
Write-Host "  Application:  https://fichajes.biedma.com" -ForegroundColor White
Write-Host "  Grafana:      http://87.106.125.173:3000 (admin/admin123)" -ForegroundColor White
Write-Host "  Prometheus:   http://87.106.125.173:9090" -ForegroundColor White
Write-Host ""
