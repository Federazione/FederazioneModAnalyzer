Add-Type -AssemblyName PresentationFramework

# Nasconde console
Add-Type -Name Win -Namespace Native -MemberDefinition '
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'
[Native.Win]::ShowWindow([Native.Win]::GetConsoleWindow(), 0)

$base = "https://raw.githubusercontent.com/Federazione/FederazioneModAnalyzer/main"
$xaml = irm "$base/ui.xaml"
$reader = New-Object System.Xml.XmlNodeReader $xaml
$Window = [Windows.Markup.XamlReader]::Load($reader)

$core = "$PSScriptRoot/core"
. "$core/helpers.ps1"

$Log = $Window.FindName("LogBox")
$Bar = $Window.FindName("Progress")

function Log($t) {
    $Log.AppendText("$t`n")
    $Log.ScrollToEnd()
}

function Step($pct) {
    $Bar.Value = $pct
}

$Window.FindName("BtnSystem").Add_Click({
    Step 10; Log "SYSTEM INFO"
    . "$core/system.ps1"
})

$Window.FindName("BtnBam").Add_Click({
    Step 25; Log "BAM ANALYSIS"
    . "$core/bam.ps1"
})

$Window.FindName("BtnUSB").Add_Click({
    Step 40; Log "USB HISTORY"
    . "$core/usb.ps1"
})

$Window.FindName("BtnMods").Add_Click({
    Step 70; Log "MOD SCAN"
    . "$core/mods.ps1"
})

$Window.FindName("BtnRecycle").Add_Click({
    Step 85; Log "RECYCLE BIN"
    . "$core/recycle.ps1"
})

$Window.FindName("BtnAll").Add_Click({
    Step 5;  Log "START FULL SCAN"
    . "$core/system.ps1"
    Step 20; . "$core/bam.ps1"
    Step 40; . "$core/usb.ps1"
    Step 65; . "$core/mods.ps1"
    Step 85; . "$core/recycle.ps1"
    Step 95; . "$core/report.ps1"
    Step 100; Log "SCAN COMPLETED"
})

$Window.ShowDialog() | Out-Null
