#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Načítá existující .sys drivery pro testování telemetrie (BYOVD Sysmon EID 6).
.DESCRIPTION
    Skript projde zadaný adresář, najde .sys soubory a pro každý vytvoří dočasnou kernel službu.
    S přepínačem -Cleanup všechny vytvořené služby zastaví a odstraní.
#>

param (
    [string]$DriverDir = "C:\PoC\BYOVD",
    [switch]$Cleanup
)

if (-not (Test-Path $DriverDir)) {
    Write-Error "Adresář '$DriverDir' neexistuje. Ujisti se, že tam máš stažené .sys soubory."
    exit
}

$Drivers = Get-ChildItem -Path $DriverDir -Filter "*.sys"

if ($Drivers.Count -eq 0) {
    Write-Warning "V adresáři '$DriverDir' nebyly nalezeny žádné .sys soubory."
    exit
}

foreach ($Driver in $Drivers) {
    # Použijeme jméno souboru (bez .sys) jako název služby. Např. RTCore64.sys -> Služba: RTCore64
    $ServiceName = $Driver.BaseName
    $DriverPath = $Driver.FullName

    if ($Cleanup) {
        Write-Host "[CLEANUP] Odstraňuji driver/službu: $ServiceName" -ForegroundColor Yellow
        
        # Zastavení služby
        $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq 'Running') {
            & sc.exe stop $ServiceName | Out-Null
            Start-Sleep -Seconds 1
        }
        
        # Smazání služby
        & sc.exe delete $ServiceName | Out-Null
        Write-Host "  -> Smazáno." -ForegroundColor Green
    }
    else {
        Write-Host "[DEPLOY] Instaluji a spouštím driver: $ServiceName" -ForegroundColor Cyan
        Write-Host "  Cesta: $DriverPath"
        
        # 1. Registrace driveru (Vytvoří System Event ID 7045)
        # Pozor na syntaxi sc.exe (mezera za rovnítkem je nutná!)
        $createResult = & sc.exe create $ServiceName type= kernel start= demand error= ignore binPath= "`"$DriverPath`""
        
        if ($LASTEXITCODE -eq 0 -or $createResult -match "SUCCESS") {
            Write-Host "  -> Služba vytvořena úspěšně."
        } else {
            Write-Warning "  -> Službu se nepodařilo vytvořit. (Možná už existuje?)"
        }

        # 2. Spuštění driveru / Load do kernelu (Vytvoří Sysmon Event ID 6)
        Write-Host "  -> Načítám $ServiceName do kernelu..."
        & sc.exe start $ServiceName | Out-Null
        
        $checkSvc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($checkSvc.Status -eq 'Running') {
            Write-Host "  -> ÚSPĚCH: Driver beží. (Čekej na logy v backendu)" -ForegroundColor Green
        } else {
            Write-Warning "  -> Driver se nespustil. (Může být blokován pomocí Windows HVCI/Blocklistu)."
        }
        
        Write-Host "---------------------------------------------------"
    }
}

if (-not $Cleanup) {
    Write-Host "`nTelemetrie by nyní měla letět do tvého LLM. Až budeš hotov, zavolej:" -ForegroundColor Magenta
    Write-Host ".\\Test-Drivers.ps1 -Cleanup" -ForegroundColor Magenta
}
