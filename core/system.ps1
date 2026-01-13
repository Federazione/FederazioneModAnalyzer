$info = @(
    "User: $env:USERNAME"
    "OS: $((Get-CimInstance Win32_OperatingSystem).Caption)"
    "Build: $((Get-CimInstance Win32_OperatingSystem).BuildNumber)"
)

$info | ForEach-Object { Log $_ }
Save "system.txt" $info
