$bam = "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings"
$out = @()

if (Test-Path $bam) {
    Get-ChildItem $bam | ForEach-Object {
        $props = (Get-ItemProperty $_.PSPath).PSObject.Properties.Name
        foreach ($p in $props) {
            if ($p -match "\.exe|\.jar") {
                $out += $p
                Log "[BAM] $p"
            }
        }
    }
}

Save "bam.txt" $out
