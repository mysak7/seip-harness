# SEIP Harness — Atomic Red Team Test Harness

Tento repozitář obsahuje skripty pro instalaci a spouštění Atomic Red Team testů na izolované Windows 11 VM za účelem testování Fluent Bit / Sysmon detekční pipeline.

---

## Požadavky

- Windows 11 VM (izolovaná od produkce)
- PowerShell 5.1 nebo novější
- Připojení k internetu (pro stažení Atomics)
- Spuštění jako **Administrátor**

---

## Soubor 1: Instalace (`Install-ART.ps1`)

Spusť tento skript **jednou** v izolované VM jako Administrátor. Skript:

1. Dočasně vypne Windows Defender Real-time a Tamper Protection (nutné pro stažení Atomics bez jejich smazání)
2. Přidá `C:\AtomicRedTeam` do výjimek Defenderu
3. Nainstaluje PowerShell modul `Invoke-AtomicRedTeam` z GitHubu (Red Canary)
4. Stáhne složku `atomics` i s testovacími payloady do `C:\AtomicRedTeam`
5. Znovu zapne Real-Time ochranu

```powershell
# Spusť jako Administrátor:
.\Install-ART.ps1
```

> **Poznámka:** `DisableTamperProtection` vyžaduje na Windows 11 ruční vypnutí přes GUI (Zabezpečení Windows → Ochrana před viry → Nastavení ochrany) nebo přes Microsoft Intune/GPO. Pokud příkaz selže, vypni Tamper Protection ručně před spuštěním skriptu.

---

## Soubor 2: Spouštění testů

Po instalaci zůstaň v Administrátorském PowerShell okně a načti modul:

```powershell
Import-Module "C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1" -Force
```

### Základní příkazy

| Akce | Příkaz |
|------|--------|
| Vypsat detaily testu | `Invoke-AtomicTest T1055.012 -ShowDetails` |
| Zkontrolovat prerekvizity | `Invoke-AtomicTest T1055.012 -CheckPrereqs` |
| Nainstalovat prerekvizity | `Invoke-AtomicTest T1055.012 -GetPrereqs` |
| Spustit test | `Invoke-AtomicTest T1055.012` |
| Uklidit po testu | `Invoke-AtomicTest T1055.012 -Cleanup` |

### Příklady

```powershell
# Vypsání detailů pro Process Injection: Process Ghosting
Invoke-AtomicTest T1055.012 -ShowDetails

# Prerekvizity pro BYOVD (Bring Your Own Vulnerable Driver)
Invoke-AtomicTest T1068 -CheckPrereqs
Invoke-AtomicTest T1068 -GetPrereqs

# Spuštění testu a následný úklid
Invoke-AtomicTest T1059.001
Invoke-AtomicTest T1059.001 -Cleanup
```

---

## Workflow pro testování detekce

1. Spusť test v izolované VM
2. Zkontroluj logy ve Fluent Bit / Sysmon pipeline
3. Ověř, zda byl útok detekován správně
4. Proveď cleanup
5. Iteruj a vylepšuj detekční pravidla

---

## Důležité upozornění

Tyto skripty jsou určeny **výhradně pro izolovaná testovací prostředí**. Nikdy je nespouštěj na produkčních systémech nebo síti.
