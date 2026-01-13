$out = @()
Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\*" -ErrorAction SilentlyContinue |
ForEach-Object {
    if ($_.FriendlyName) {
        $out += $_.FriendlyName
        Log "[USB] $($_.FriendlyName)"
    }
}

Save "usb.txt" $out
