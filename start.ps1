# ============================================================
# QUANTARA — Démarrage manuel du dashboard
# Usage : .\start.ps1
# ============================================================
$ErrorActionPreference = "Stop"
$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
$WEB  = Join-Path $ROOT "web"

Write-Host "`n=== QUANTARA Start ===" -ForegroundColor Yellow

# Vérifier que le build existe
if (-not (Test-Path (Join-Path $WEB ".next"))) {
    Write-Host "[!] Pas de build detecte, lancement du build..." -ForegroundColor Red
    Push-Location $WEB
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "Build failed" }
    Pop-Location
    Write-Host "  Build OK`n" -ForegroundColor Green
}

# Arrêter l'ancien processus Next.js s'il tourne sur le port 4240
$existing = Get-NetTCPConnection -LocalPort 4240 -ErrorAction SilentlyContinue
if ($existing) {
    $pids = $existing | Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($pid in $pids) {
        Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  Ancien processus sur :4240 arrete" -ForegroundColor DarkGray
}

# Démarrer Next.js
Write-Host "Demarrage Next.js sur port 4240..." -ForegroundColor Cyan
Push-Location $WEB
node node_modules\next\dist\bin\next start --port 4240
