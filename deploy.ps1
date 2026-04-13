# ============================================================
# QUANTARA — Script de déploiement (Windows / PowerShell)
# Usage : .\deploy.ps1
# ============================================================
param(
    [switch]$SkipBuild,
    [switch]$SkipApache
)

$ErrorActionPreference = "Stop"
$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "`n=== QUANTARA Deploy ===" -ForegroundColor Yellow

# ── 1. Build Next.js ──────────────────────────────────────────
if (-not $SkipBuild) {
    Write-Host "`n[1/4] Building Next.js dashboard..." -ForegroundColor Cyan
    Push-Location "$ROOT\web"
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "Next.js build failed" }
    Pop-Location
    Write-Host "  ✓ Build OK" -ForegroundColor Green
} else {
    Write-Host "`n[1/4] Skipping build (--SkipBuild)" -ForegroundColor DarkGray
}

# ── 2. Copier config Apache ──────────────────────────────────
if (-not $SkipApache) {
    Write-Host "`n[2/4] Installing Apache vhost config..." -ForegroundColor Cyan
    $vhostSrc  = "$ROOT\backend\apache\quantara-vhost.conf"
    $vhostDest = "C:\xampp\apache\conf\extra\quantara-vhost.conf"

    Copy-Item $vhostSrc $vhostDest -Force
    Write-Host "  ✓ Copied to $vhostDest" -ForegroundColor Green

    # Vérifie que le Include existe dans httpd-vhosts.conf
    $vhostsConf = "C:\xampp\apache\conf\extra\httpd-vhosts.conf"
    $includeLine = 'Include "conf/extra/quantara-vhost.conf"'
    $content = Get-Content $vhostsConf -Raw
    if ($content -notmatch [regex]::Escape($includeLine)) {
        Add-Content $vhostsConf "`n# QUANTARA`n$includeLine`n"
        Write-Host "  ✓ Added Include directive to httpd-vhosts.conf" -ForegroundColor Green
    } else {
        Write-Host "  · Include already present" -ForegroundColor DarkGray
    }

    # Test config Apache
    Write-Host "  Testing Apache config..." -ForegroundColor DarkGray
    & "C:\xampp\apache\bin\httpd.exe" -t 2>&1 | ForEach-Object { Write-Host "    $_" }
} else {
    Write-Host "`n[2/4] Skipping Apache (--SkipApache)" -ForegroundColor DarkGray
}

# ── 3. Redémarrer le service Next.js ─────────────────────────
Write-Host "`n[3/4] Starting Next.js on port 4240..." -ForegroundColor Cyan

# Arrête l'ancien processus s'il tourne
$existing = Get-Process -Name "node" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match "next.*4240" }
if ($existing) {
    $existing | Stop-Process -Force
    Write-Host "  · Stopped previous Next.js process" -ForegroundColor DarkGray
}

# Démarre en background
Push-Location "$ROOT\web"
Start-Process -FilePath "npm" -ArgumentList "run", "start" -WindowStyle Hidden -WorkingDirectory "$ROOT\web"
Pop-Location
Write-Host "  ✓ Next.js started (http://127.0.0.1:4240/quantara)" -ForegroundColor Green

# ── 4. Redémarrer Apache ─────────────────────────────────────
if (-not $SkipApache) {
    Write-Host "`n[4/4] Restarting Apache..." -ForegroundColor Cyan
    & "C:\xampp\apache\bin\httpd.exe" -k restart 2>&1 | ForEach-Object { Write-Host "    $_" }
    Write-Host "  ✓ Apache restarted" -ForegroundColor Green
} else {
    Write-Host "`n[4/4] Skipping Apache restart" -ForegroundColor DarkGray
}

Write-Host "`n=== Deploy complete ===" -ForegroundColor Yellow
Write-Host "Dashboard : https://juniari.com/quantara/dashboard" -ForegroundColor Green
Write-Host "Local dev : http://localhost:4240/quantara/dashboard`n" -ForegroundColor DarkGray
