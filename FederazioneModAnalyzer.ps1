# ===================== CHECK ADMIN CORRETTO =====================
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Richiesta privilegi SYSTEM/ADMIN..." -ForegroundColor Red
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$ErrorActionPreference = "SilentlyContinue"
Clear-Host
$host.UI.RawUI.WindowTitle = "FEDERAZIONE GOD MODE - LIVE FORENSICS"

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$evidencePath = "$env:USERPROFILE\Desktop\FEDERAZIONE_EVIDENCE_$timestamp"
New-Item -ItemType Directory -Path $evidencePath -Force | Out-Null
$logFile = "$evidencePath\FULL_REPORT.txt"

function Log-Write {
    param (
        [string]$Msg,
        [string]$Color = "White",
        [bool]$Header = $false
    )

    if ($Header) {
        Write-Host "`n========================================================" -ForegroundColor Cyan
        Write-Host " $Msg" -ForegroundColor Cyan
        Write-Host "========================================================" -ForegroundColor Cyan
        "========================================================`n $Msg`n========================================================" |
            Out-File $logFile -Append
    } else {
        Write-Host $Msg -ForegroundColor $Color
        $Msg | Out-File $logFile -Append
    }
}

function Dump-ModContent {
    param ($jarPath, $jarName)

    Log-Write "[DUMP] Estrazione codice sorgente/stringhe per: $jarName" -Color Yellow

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

            $keywords = $text |
                Select-String "[a-zA-Z0-9_]{4,}" -AllMatches |
                Select-Object -ExpandProperty Matches |
                Select-Object -ExpandProperty Value

            if ($keywords) {
                "`n[FILE: $($f.Name)]" | Out-File $dumpFile -Append
                ($keywords -join " ") | Out-File $dumpFile -Append
            }
        }

        Log-Write "   -> Dump salvato in: $dumpFile" -Color Green
    }
    catch {
        Log-Write "   -> Errore durante il dump: $($_.Exception.Message)" -Color Red
    }
    finally {
        Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Log-Write "FEDERAZIONE GOD MODE - AVVIATO" -Header $true
Log-Write "Target User: $env:USERNAME"
Log-Write "OS Version: $((Get-CimInstance Win32_OperatingSystem).Caption)"
Log-Write "Analisi salvata in: $evidencePath" -Color Magenta

Log-Write "ANALISI BAM/DAM (Esecuzioni Nascoste)" -Header $true
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

Log-Write "ANALISI EVENTI DI SISTEMA (Kernel Drivers)" -Header $true
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

Log-Write "ANALISI DISPOSITIVI USB" -Header $true
try {
    Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\*" |
    ForEach-Object {
        if ($_.FriendlyName) {
            Log-Write "Dispositivo connesso in passato: $($_.FriendlyName)" -Color DarkGray
        }
    }
}
catch {}

Log-Write "ANALISI FILE APERTI DI RECENTE (OpenSaveMRU)" -Header $true
try {
    $mruPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU"
    if (Test-Path $mruPath) {
        Get-ChildItem $mruPath | ForEach-Object {
            if ($_.PSChildName -match "exe|jar|dll") {
                Log-Write "Estensione frequentata: .$($_.PSChildName)" -Color Yellow
            }
        }
    }
}
catch {}

Log-Write "ANALISI PROFONDA MODS & DUMPING" -Header $true
$modsDir = "$env:APPDATA\.minecraft\mods"
Write-Host "Path mods (Enter per default): " -NoNewline
$inputMods = Read-Host
if ($inputMods) { $modsDir = $inputMods }

if (Test-Path $modsDir) {
    $cheatStrings = @(
        "AimAssist","AutoClicker","KillAura","Reach","Velocity","Hitboxes",
        "Wurst","Vape","Konas","Meteor","Inertia","Bleach","Cornos","Aristois"
    )

    Get-ChildItem $modsDir -Filter *.jar | ForEach-Object {
        $jar = $_
        Write-Host "Scanning: $($jar.Name)" -NoNewline
        $raw = Get-Content -Raw $jar.FullName
        $detected = $false

        foreach ($s in $cheatStrings) {
            if ($raw -match $s) {
                Log-Write "`n[DETECTED] Cheat confermato in $($jar.Name): $s" -Color Red
                $detected = $true
                break
            }
        }

        if ($detected -or ($jar.Name -notmatch "optifine|fabric")) {
            Dump-ModContent $jar.FullName $jar.Name
        } else {
            Write-Host " [SAFE]" -ForegroundColor Green
        }
    }
} else {
    Log-Write "Cartella mods non trovata." -Color Red
}

Log-Write "ANALISI USN JOURNAL (File System History)" -Header $true
try {
    $usnTemp = "$env:TEMP\usn_dump.txt"
    fsutil usn readjournal C: csv | Select-Object -Last 3000 > $usnTemp

    $patterns = "Vape|Clicker|Auto|Reach|Killaura|\.jar|\.exe"
    Get-Content $usnTemp | ForEach-Object {
        if ($_ -match "FileDelete|FileCreate" -and $_ -match $patterns) {
            $clean = $_ -replace '[,"]',' ' -replace '\s+',' '
            Log-Write "[USN TRACE] $clean" -Color Red
        }
    }

    Remove-Item $usnTemp -Force
}
catch {
    Log-Write "Impossibile leggere USN Journal." -Color Red
}

Log-Write "ANALISI CESTINO" -Header $true
$shell = New-Object -ComObject Shell.Application
$bin = $shell.NameSpace(0xa)

foreach ($item in $bin.Items()) {
    if ($item.Name -match "\.jar|\.exe|\.dll") {
        Log-Write "[CESTINO] $($item.Name) (Origine: $($item.Path))" -Color Red
    }
}

Log-Write "ANALISI GOD MODE COMPLETATA." -Header $true
Log-Write "TUTTE LE PROVE SONO IN: $evidencePath" -Color Magenta
Invoke-Item $evidencePath
Read-Host "Premi INVIO per terminare..."
