#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Připraví bezpečné systémové drivery pro testování telemetrie (Sysmon EID 6 / System 7045).
.DESCRIPTION
    Zkopíruje vestavěné Windows drivery (beep.sys, null.sys) do testovacího adresáře pod
    testovacími jmény. Žádný skutečný zranitelný driver – pouze validace detekčního pipeline.
.EXAMPLE
    .\Prepare-SafeDrivers.ps1
    .\Prepare-SafeDrivers.ps1 -DestDir "D:\TestDrivers"
#>

param (
    [string]$DestDir = "c:\Users\Seip\Documents\Git\seip-harness\BYOVDKit\Drivers"
)

# 1. Ujistíme se, že cílový adresář existuje
if (-not (Test-Path $DestDir)) {
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    Write-Host "[+] Adresář vytvořen: $DestDir" -ForegroundColor Green
} else {
    Write-Host "[*] Adresář již existuje: $DestDir" -ForegroundColor Yellow
}

# 2. Definice bezpečných driverů k použití jako testovací vzorky
$SafeDrivers = @(
    @{ Src = "C:\Windows\System32\drivers\beep.sys"; Dst = "$DestDir\test_beep.sys" },
    @{ Src = "C:\Windows\System32\drivers\null.sys"; Dst = "$DestDir\test_null.sys" }
)

# 3. Kopírování
$Copied = 0
foreach ($Entry in $SafeDrivers) {
    if (Test-Path $Entry.Src) {
        Copy-Item -Path $Entry.Src -Destination $Entry.Dst -Force
        $Hash = (Get-FileHash -Path $Entry.Dst -Algorithm SHA256).Hash
        Write-Host "[+] Zkopírován: $($Entry.Dst)" -ForegroundColor Green
        Write-Host "    SHA256: $Hash"
        $Copied++
    } else {
        Write-Warning "[-] Zdroj nenalezen, přeskakuji: $($Entry.Src)"
    }
}

# 4. Výsledek
Write-Host ""
if ($Copied -gt 0) {
    Write-Host "Hotovo! $Copied bezpečný/e driver(y) připraven(y) v '$DestDir'." -ForegroundColor Green
    Write-Host "Nyní spusť:  .\Test-Drivers.ps1 -DriverDir '$DestDir'" -ForegroundColor Cyan
} else {
    Write-Error "Žádný driver nebyl zkopírován. Zkontroluj cestu ke zdrojům."
    exit 1
}
