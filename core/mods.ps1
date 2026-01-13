$mods = "$env:APPDATA\.minecraft\mods"
if (!(Test-Path $mods)) { Log "Mods not found"; return }

$cheats = "meteor","vape","wurst","killaura","reach","aim","velocity"
$out = @()

Get-ChildItem $mods -Filter *.jar | ForEach-Object {

$hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
$raw = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue

$status = "SAFE"
foreach ($c in $cheats) {
if ($raw -match $c) { $status = "CHEAT"; break }
}
if ($status -eq "SAFE" -and $_.Name -notmatch "fabric|api|sodium|lithium|optifine") {
$status = "UNKNOWN"
}

Log "[$status] $($_.Name)"
$out += "[$status] $($_.Name) | SHA256=$hash"

if ($status -ne "SAFE") {
Add-Type -AssemblyName System.IO.Compression.FileSystem
$tmp = "$env:TEMP\$($_.BaseName)"
[IO.Compression.ZipFile]::ExtractToDirectory($_.FullName, $tmp)

$dump = @()
Get-ChildItem $tmp -Recurse | Sort-Object FullName | ForEach-Object {
$dump += "FILE: $($_.FullName.Replace($tmp,''))"
}

Save "$($_.Name).dump.txt" $dump
Remove-Item $tmp -Recurse -Force
}
}

Save "mods.txt" $out
