$shell = New-Object -ComObject Shell.Application
$bin = $shell.NameSpace(0xA)
$out = @()

foreach ($i in $bin.Items()) {
    if ($i.Name -match "\.jar|\.exe|\.dll") {
        Log "[BIN] $($i.Name)"
        $out += $i.Name
    }
}

Save "recycle.txt" $out
