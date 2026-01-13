# =========================================================
# FEDERAZIONE MOD ANALYZER - FORENSIC SUITE
# Versione: 5.0
# =========================================================

# Richiesta privilegi amministrativi
if (-not (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))) {
    Write-Host "Richiesta privilegi ADMIN..." -ForegroundColor Red
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# Impostazioni generali
$ErrorActionPreference = "SilentlyContinue"
Clear-Host
$host.UI.RawUI.WindowTitle = "Federazione Mod Analyzer"

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$evidencePath = "$env:USERPROFILE\Desktop\FEDERAZIONE_EVIDENCE_$timestamp"
New-Item -ItemType Directory -Path $evidencePath -Force | Out-Null
$logFile = "$evidencePath\FULL_REPORT.txt"

# Funzione log
function Log-Write {
    param(
        [string]$Msg,
        [string]$Color = "White",
        [bool]$Header = $false
    )
    if ($Header) {
        Write-Host "`n========================================================" -ForegroundColor Red
        Write-Host " $Msg" -ForegroundColor Red
        Write-Host "========================================================`n" -ForegroundColor Red
        "========================================================`n $Msg`n========================================================" | Out-File $logFile -Append
    } else {
        Write-Host $Msg -ForegroundColor $Color
        $Msg | Out-File $logFile -Append
    }
}

# Funzione per dump dei file jar
function Dump-ModContent {
    param ($jarPath, $jarName)

    Log-Write "[DUMP] Estrazione codice sorgente/stringhe: $jarName" -Color Yellow
    $dumpFile = "$evidencePath\$jarName.DUMP.txt"
    $tempExtract = "$env:TEMP\FedAnalyzer_$((Get-Random))"

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($jarPath, $tempExtract)

        "--- DUMP ANALISI $jarName ---" | Out-File $dumpFile
        "--- HASH: $((Get-FileHash $jarPath).Hash) ---`n" | Out-File $dumpFile -Append

        $files = Get-ChildItem $tempExtract -Recurse -Include *.class, *.yml, *.json, *.txt

        foreach ($f in $files) {
            $bytes = Get-Content $f.FullName -Encoding Byte -ReadCount 0
            $text = ($bytes | Where-Object { $_ -ge 32 -and $_ -le 126 } | ForEach-Object { [char]$_ }) -join ""
            $keywords = $text | Select-String "[a-zA-Z0-9_]{4,}" -AllMatches | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
            if ($keywords) {
                "`n[FILE: $($f.Name)]" | Out-File $dumpFile -Append
                ($keywords -join " ") | Out-File $dumpFile -Append
            }
        }

        Log-Write " -> Dump salvato in: $dumpFile" -Color Green
    } catch {
        Log-Write " -> Errore durante il dump: $($_.Exception.Message)" -Color Red
    } finally {
        Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# =========================================================
# INFORMAZIONI SISTEMA
# =========================================================
Log-Write "ANALISI SISTEMA AVVIATA" -Header $true
Log-Write "Target User: $env:USERNAME"
Log-Write "OS Version: $((Get-CimInstance Win32_OperatingSystem).Caption)"
Log-Write "Cartella risultati: $evidencePath" -Color Magenta

# =========================================================
# ANALISI BAM/DAM
# =========================================================
Log-Write "ANALISI ESECUZIONI NASCOSTE (BAM/DAM)" -Header $true
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

# =========================================================
# ANALISI EVENTI DI SISTEMA
# =========================================================
Log-Write "ANALISI EVENTI DI SISTEMA (Kernel Drivers)" -Header $true
try {
    Get-WinEvent -FilterHashtable @{LogName='System'; ID=7045} -MaxEvents 50 |
    ForEach-Object {
        if ($_.Message -match "mhyprot|VBox|kprocesshacker|Echo") {
            Log-Write "[CRITICO DRIVER] $($_.Message)" -Color Red
        }
    }
} catch {
    Log-Write "Impossibile leggere Event Log System." -Color Red
}

# =========================================================
# ANALISI DISPOSITIVI USB
# =========================================================
Log-Write "ANALISI DISPOSITIVI USB" -Header $true
try {
    Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\*" |
    ForEach-Object {
        if ($_.FriendlyName) {
            Log-Write "Dispositivo connesso in passato: $($_.FriendlyName)" -Color DarkGray
        }
    }
} catch {}

# =========================================================
# FILE APERTI DI RECENTE
# =========================================================
Log-Write "ANALISI FILE APERTI DI RECENTE" -Header $true
try {
    $mruPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU"
    if (Test-Path $mruPath) {
        Get-ChildItem $mruPath | ForEach-Object {
            if ($_.PSChildName -match "exe|jar|dll") {
                Log-Write "Estensione frequentata: .$($_.PSChildName)" -Color Yellow
            }
        }
    }
} catch {}

# =========================================================
# ANALISI MODS
# =========================================================
Log-Write "ANALISI MODS MINECRAFT" -Header $true
$modsDir = "$env:APPDATA\.minecraft\mods"
Write-Host "Path mods (Enter per default): " -NoNewline
$inputMods = Read-Host
if ($inputMods) { $modsDir = $inputMods }

$cheatStrings = @(
    "AimAssist","AutoClicker","KillAura","Reach","Velocity","Hitboxes",
    "Wurst","Vape","Konas","Meteor","Inertia","Bleach","Cornos","Aristois"
)

$results = @()
if (Test-Path $modsDir) {
    Get-ChildItem $modsDir -Filter *.jar | ForEach-Object {
        $jar = $_
        $jarName = $jar.Name
        $raw = Get-Content -Raw $jar.FullName
        $status = "SAFE"
        $matchString = ""

        foreach ($s in $cheatStrings) {
            if ($raw -match $s) {
                $status = "CHEAT"
                $matchString = $s
                break
            }
        }

        if ($status -eq "CHEAT") {
            Log-Write "[$status] $jarName (pattern: $matchString)" -Color Red
            Dump-ModContent -jarPath $jar.FullName -jarName $jarName
        } else {
            Log-Write "[$status] $jarName" -Color Green
        }

        $results += [PSCustomObject]@{
            Name   = $jarName
            Status = $status
            Match  = $matchString
        }
    }

    # Riepilogo
    Log-Write "`nRIEPILOGO MODS" -Header $true
    $results | ForEach-Object {
        switch ($_.Status) {
            "SAFE"  { Write-Host ("SAFE  : " + $_.Name) -ForegroundColor Green }
            "CHEAT" { Write-Host ("CHEAT : " + $_.Name + " (" + $_.Match + ")") -ForegroundColor Red }
            default { Write-Host ("UNKNOWN : " + $_.Name) -ForegroundColor Yellow }
        }
    }
} else {
    Log-Write "Cartella mods non trovata." -Color Red
}

# =========================================================
# ANALISI CESTINO
# =========================================================
Log-Write "ANALISI CESTINO" -Header $true
$shell = New-Object -ComObject Shell.Application
$bin = $shell.NameSpace(0xa)
foreach ($item in $bin.Items()) {
    if ($item.Name -match "\.jar|\.exe|\.dll") {
        Log-Write "[Cestino] $($item.Name) (Origine: $($item.Path))" -Color Red
    }
}

# =========================================================
# COMPLETAMENTO ANALISI
# =========================================================
Log-Write "ANALISI COMPLETATA" -Header $true
Log-Write "Tutti i risultati in: $evidencePath" -Color Magenta
Invoke-Item $evidencePath
Read-Host "Premi INVIO per terminare..."

