Add-Type -AssemblyName PresentationFramework

$xaml = irm https://raw.githubusercontent.com/Federazione/FederazioneModAnalyzer/main/ui.xaml
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$Window = [Windows.Markup.XamlReader]::Load($reader)

$LogBox = $Window.FindName("LogBox")

function Write-Log($msg) {
    $LogBox.AppendText("$msg`n")
    $LogBox.ScrollToEnd()
}

$Window.FindName("BtnSystem").Add_Click({
    Write-Log "[SYSTEM] Raccolta informazioni..."
    . "$PSScriptRoot\core\system.ps1"
})

$Window.FindName("BtnMods").Add_Click({
    Write-Log "[MODS] Avvio scansione..."
    . "$PSScriptRoot\core\mods.ps1"
})

$Window.ShowDialog() | Out-Null
