# =============================================================================
# FEDERAZIONE MOD ANALYZER - FORENSIC SUITE
# Versione: 4.5
# Author: System Integrity Division
# =============================================================================

# Verifica privilegi amministratore
if (-not ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))) {
    Write-Host "Richiesta privilegi ADMIN..." -ForegroundColor Red
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

$ErrorActionPreference = "SilentlyContinue"
Clear-Host
$host.UI.RawUI.WindowTitle = "FEDERAZIONE MOD ANALYZER"

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$evidencePath = "$env:USERPROFILE\Desktop\FEDERAZIONE_EVIDENCE_$timestamp"
New-Item -ItemType Directory -Path $evidencePath -Force | Out-Null
$logFile = "$evidencePath\FULL_REPORT.txt"

# Funzione log
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

# Funzione per dump delle mod
function Dump-ModContent {
    param ($jarPath, $jarName)

    Log-Write "[DUMP] Estrazione codice sorgente per: $jarName" -Color Yellow

    $dumpFile = "$evidencePath\$jarName.DUMP.txt"
    $tempExtract = "$env:TEMP\FedAnalyzer_$((Get-Random))"

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($jarPath, $tempExtract)

        "--- DUMP ANALISI PER $jarName ---" | Out-File $dumpFile
        "--- HASH: $((Get-FileHash $jarPath).Hash) ---`n" | Out-File $dumpFile -Append

        $files = Get-ChildItem $tempExtract -Recurse -Include *.class, *.yml, *.json, *.txt

        foreach ($f in $files) {
            $bytes = Get-Content $f.FullName -Encoding Byte -ReadCount 0
            $text = ($bytes | Where-Object { $_ -ge 32 -and $_ -le 126 } | ForEach-Object { [char]$_ }) -join ""
            $keywords = $text | Select-String "[a-zA-Z0-9_]{4,}" -AllMatches | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value

            if ($keywords) {
                "`n[FILE: $($f.Name)]`n" | Out-File $dumpFile -Append
                ($keywords -join "`n") | Out-File $dumpFile -Append
            }
        }

        Log-Write "   -> Dump salvato in: $dumpFile" -Color Green
    } catch {
        Log-Write "   -> Errore durante il dump: $($_.Exception.Message)" -Color Red
    } finally {
        Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# =========================================================
# INFO SISTEMA
# =========================================================
Log-Write "INFORMAZIONI SISTEMA" -Header $true
Log-Write "Target User: $env:USERNAME"
Log-Write "OS Version: $((Get-CimInstance Win32_OperatingSystem).Caption)"
Log-Write "Analisi salvata in: $evidencePath" -Color Magenta

# =========================================================
# BAM/DAM - Esecuzioni Nascoste
# =========================================================
Log-Write "ESECUZIONI NASCOSTE (BAM/DAM)" -Header $true
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
} else {
    Log-Write "Cartella BAM non disponibile." -Color Yellow
}

# =========================================================
# DRIVER DI SISTEMA
# =========================================================
Log-Write "EVENTI KERNEL / DRIVER" -Header $true
try {
    Get-WinEvent -FilterHashtable @{LogName='System'; ID=7045} -MaxEvents 50 | ForEach-Object {
        if ($_.Message -match "mhyprot|VBox|kprocesshacker|Echo") {
            Log-Write "[CRITICO DRIVER] $($_.Message)" -Color Red
        }
    }
} catch {
    Log-Write "Impossibile leggere Event Log System." -Color Red
}

# =========================================================
# USB
# =========================================================
Log-Write "DISPOSITIVI USB COLLEGATI" -Header $true
try {
    Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\*" | ForEach-Object {
        if ($_.FriendlyName) {
            Log-Write "Dispositivo: $($_.FriendlyName)" -Color DarkGray
        }
    }
} catch {}

# =========================================================
# FILE APERTI DI RECENTE
# =========================================================
Log-Write "FILE APERTI DI RECENTE" -Header $true
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
# MODS ANALISI
# =========================================================
Log-Write "ANALISI MODS" -Header $true
$modsDir = "$env:APPDATA\.minecraft\mods"
Write-Host "Path mods (Enter per default): " -NoNewline
$inputMods = Read-Host
if ($inputMods) { $modsDir = $inputMods }

if (Test-Path $modsDir) {
    $cheatStrings = @(
        "AimAssist","AutoClicker","KillAura","Reach","Velocity","Hitboxes",
        "Wurst","Vape","Konas","Meteor","Inertia","Bleach","Cornos","Aristois"
    )

    $mods = Get-ChildItem $modsDir -Filter *.jar | Sort-Object Name

    foreach ($jar in $mods) {
        $rawContent = Get-Content -Raw $jar.FullName
        $status = "SAFE"
        $detectedCheat = $null

        foreach ($s in $cheatStrings) {
            if ($rawContent -match $s) {
                $status = "CHEAT"
                $detectedCheat = $s
                break
            }
        }

        if ($status -eq "CHEAT") {
            Log-Write "[DETECTED] $($jar.Name) → $detectedCheat" -Color Red
        } else {
            Log-Write "[SAFE] $($jar.Name)" -Color Green
        }

        if ($status -eq "CHEAT" -or ($jar.Name -notmatch "optifine|fabric")) {
            Dump-ModContent $jar.FullName $jar.Name
        }
    }
} else {
    Log-Write "Cartella mods non trovata." -Color Red
}

# =========================================================
# CESTINO
# =========================================================
Log-Write "CONTENUTO CESTINO" -Header $true
$shell = New-Object -ComObject Shell.Application
$bin = $shell.NameSpace(0xa)

foreach ($item in $bin.Items()) {
    if ($item.Name -match "\.jar|\.exe|\.dll") {
        Log-Write "[CESTINO] $($item.Name) (Origine: $($item.Path))" -Color Red
    }
}

# =========================================================
# FINE ANALISI
# =========================================================
Log-Write "ANALISI COMPLETATA" -Header $true
Log-Write "TUTTE LE PROVE SONO IN: $evidencePath" -Color Magenta
Invoke-Item $evidencePath
Read-Host "Premi INVIO per terminare..."


