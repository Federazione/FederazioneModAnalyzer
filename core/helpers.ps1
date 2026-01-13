$global:Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$global:Evidence = "$env:USERPROFILE\Desktop\FED_EVIDENCE_$Timestamp"
New-Item $Evidence -ItemType Directory -Force | Out-Null

function Save($name, $content) {
    $path = Join-Path $Evidence $name
    $content | Out-File $path -Encoding UTF8
}
