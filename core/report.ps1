$html = @"
<html><body style='background:#0c0c0c;color:#ff3b3b;font-family:Consolas'>
<h1>Federazione Mod Analyzer Report</h1>
<pre>
$(Get-Content "$Evidence\system.txt" -Raw)

$(Get-Content "$Evidence\bam.txt" -Raw)

$(Get-Content "$Evidence\usb.txt" -Raw)

$(Get-Content "$Evidence\mods.txt" -Raw)

$(Get-Content "$Evidence\recycle.txt" -Raw)
</pre>
</body></html>
"@

$html | Out-File "$Evidence\REPORT.html"
Invoke-Item "$Evidence\REPORT.html"
