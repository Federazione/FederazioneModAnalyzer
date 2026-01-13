# =============================================================================
# FEDERAZIONE MOD ANALYZER - FORENSIC SUITE
# Version: 4.5 - Clean & Styled
# =============================================================================

# Controllo privilegi Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Richiesta privilegi Administrator..." -ForegroundColor Red
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

$ErrorActionPreference = "SilentlyContinue"
Clear-Host
$host.UI.RawUI.WindowTitle = "FEDERAZIONE MOD ANALYZER"

# Percorsi e file log
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$evidencePath = "$env:USERPROFILE\Desktop\FEDERAZIONE_EVIDENCE_$timestamp"
New-Item -ItemType Directory -Path $evidencePath -Force | Out-Null
$logFile = "$evidencePath\FULL_REPORT.txt"

# Funzione per scrivere log e output colorato
function Log-Write {
    param (
        [string]$Msg,
        [string]$Color = "White",
        [bool]$Header = $false
    )

    if ($Header) {
        Write-Host "`n========================================================" -ForegroundColor Red
        Write-Host " $Msg" -ForegroundColor Red
        Write-Host "========================================================" -ForegroundColor Red
        "========================================================`n $Msg`n========================================================" | Out-File $logFile -Append
    } else {
        Write-Host $Msg -ForegroundColor $Color
        $Msg | Out-File $logFile -Append
    }
}

# Funzione per estrarre codice/stringhe dai jar
function Dump-ModContent {
    param ($jarPath, $jarName)

    Log-Write "[DUMP] Analisi: $jarName" -Color Yellow
    $dumpFile = "$evidencePath\$jarName.DUMP.txt"
    $tempExtract = "$env:TEMP\FedAnalyzer_$((Get-Random))"

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($jarPath, $tempExtract)

        "--- ANALISI PER $jarName ---" | Out-File $dumpFile
        "--- HASH: $((Get-FileHash $jarPath).Hash) ---`n" | Out-File $dumpFile -Append

        $files = Get-ChildItem $tempExtract -Recurse -Include *.class, *.yml, *.json, *.txt

        foreach ($f in $files) {
            $bytes = Get-Content $f.FullName -Encoding Byte -ReadCount 0
            $text = ($bytes | Where-Object { $_ -ge 32 -and $_ -le 126 } | ForEach-Object { [char]$_ }) -join ""

            $keywords = $text |
                Select-String "[a-zA-Z0-9_]{4,}" -AllMatches |
                Select-Object -ExpandProperty Matches |
                Select-Object -ExpandProperty Value

            if ($keywords) {
                "`n[FILE: $($f.Name)]" | Out-File $dumpFile -Append
                ($keywords -join " ") | Out-File $dumpFile -Append
            }
        }

        Log-Write " -> Dump salvato: $dumpFile" -Color Green
    }
    catch {
        Log-Write " -> Errore dump: $($_.Exception.Message)" -Color Red
    }
    finally {
        Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# =====================================================================
# INIZIO ANALISI
# =====================================================================

Log-Write "ANALISI INIZIATA" -Header $true
Log-Write "Utente: $env:USERNAME"
Log-Write "Sistema operativo: $((Get-CimInstance Win32_OperatingSystem).Caption)"
Log-Write "Salvataggio prove in: $evidencePath" -Color Magenta

# ---------------------------------------------------------------------
# BAM/DAM - Processi nascosti
# ---------------------------------------------------------------------
Log-Write "BAM/DAM - Processi nascosti" -Header $true
$bamPath = "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings"

if (Test-Path $bamPath) {
    foreach ($userSid in Get-ChildItem $bamPath) {
        $entries = Get-ItemProperty $userSid.PSPath
        foreach ($name in $entries.PSObject.Properties.Name) {
            if ($name -match "\.exe|javaw") {
                if ($name -match "Clicker|Vape|AnyDesk|ProcessHacker|Echo|drip") {
                    Log-Write "[CRITICO BAM] $name" -Color Red
                }
            }
        }
    }
}

# ---------------------------------------------------------------------
# Eventi di sistema - Kernel Drivers
# ---------------------------------------------------------------------
Log-Write "Eventi di sistema (Kernel Drivers)" -Header $true
try {
    Get-WinEvent -FilterHashtable @{LogName='System'; ID=7045} -MaxEvents 50 |
        ForEach-Object {
            if ($_.Message -match "mhyprot|VBox|kprocesshacker|Echo") {
                Log-Write "[CRITICO DRIVER] $($_.Message)" -Color Red
            }
        }
}
catch {
    Log-Write "Impossibile leggere Event Log System." -Color Red
}

# ---------------------------------------------------------------------
# Dispositivi USB
# -----------------------------------------
