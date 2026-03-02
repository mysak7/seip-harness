#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Instaluje prostředí Atomic Red Team od Red Canary na Windows 11.
.DESCRIPTION
    Tento skript:
    1. Dočasně vypne Windows Defender Real-time a Tamper Protection (nutné pro stažení Atomics).
    2. Vytvoří výjimku v Defenderu pro složku C:\AtomicRedTeam.
    3. Nainstaluje PowerShell modul Invoke-AtomicRedTeam (z PSGallery nebo GitHubu).
    4. Stáhne složku "atomics" (která obsahuje návody a testovací payloady).
#>

Write-Host "=== Instalace Atomic Red Team ===" -ForegroundColor Cyan

# 1. Nastavení politik pro běh skriptů
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 2. Vypnutí Defenderu (aby nestřílel payloady při stahování zipu)
Write-Host "[1/4] Vypínám Defender (aby přežily payloady při stažení)..." -ForegroundColor Yellow
Set-MpPreference -DisableRealtimeMonitoring $true

# Kontrola Tamper Protection — na Windows 11 ji nelze vypnout přes PowerShell bez Intune/GPO
$tamperEnabled = (Get-MpComputerStatus).IsTamperProtected
if ($tamperEnabled) {
    Write-Host ""
    Write-Host "  [!] Tamper Protection je zapnuta a nelze ji vypnout skriptem." -ForegroundColor Red
    Write-Host "  [!] Vypni ji ručně a pak skript znovu spusť:" -ForegroundColor Red
    Write-Host ""
    Write-Host "      1. Otevři: Zabezpečení Windows" -ForegroundColor White
    Write-Host "         (Start → 'Windows Security')" -ForegroundColor Gray
    Write-Host "      2. Ochrana před viry a hrozbami → Nastavení ochrany" -ForegroundColor White
    Write-Host "      3. Přepni 'Ochrana před neoprávněnými změnami' na VYPNUTO" -ForegroundColor White
    Write-Host ""
    Write-Host "  Po vypnutí znovu spusť tento skript." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
Set-MpPreference -DisableTamperProtection $true

# 3. Vytvoření adresáře a výjimky (Whitelist)
$InstallPath = "C:\AtomicRedTeam"
if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath | Out-Null
}
Write-Host "[2/4] Přidávám $InstallPath do výjimek Defenderu..." -ForegroundColor Yellow
Add-MpPreference -ExclusionPath $InstallPath

# 4. Instalace modulu a Atomics (Testů)
Write-Host "[3/4] Stahuji a instaluji Invoke-AtomicRedTeam a Atomics z GitHubu..." -ForegroundColor Yellow
# Stáhneme instalační script přímo od Red Canary a rovnou ho pustíme se stažením payloadů (-getAtomics)
IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing);
Install-AtomicRedTeam -getAtomics -Force

# 5. Zapnutí Defenderu (volitelné, ale doporučené - skenovány budou procesy, ale ne soubory ve složce)
Write-Host "[4/4] Zapínám zpět Real-Time ochranu..." -ForegroundColor Yellow
Set-MpPreference -DisableRealtimeMonitoring $false

Write-Host "`n=== HOTOVO! ===" -ForegroundColor Green
Write-Host "Atomic Red Team je nainstalován v $InstallPath"
Write-Host "Nyní můžeš spustit testy pomocí příkazu: Invoke-AtomicTest <TechniqueID>"
Write-Host "Příklad pro vypsání testů pro Process Ghosting: Invoke-AtomicTest T1055.012 -ShowDetails"
