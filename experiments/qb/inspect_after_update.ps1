# Step 6.6 Diagnostics - Inspect files modified during update test and dump [Patch] channel section
$scriptDir = $PSScriptRoot
$outFile = Join-Path $scriptDir "after_update_report.txt"

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("=== Inspecting State After DoUpdateNow Test - $(Get-Date) - Host: $env:COMPUTERNAME ===")
$lines.Add("")

# 1. Check QB 2024 Qbchan.dat
$qbchan = "C:\ProgramData\Intuit\QuickBooks 2024\Components\QBUpdate\Qbchan.dat"
if (Test-Path $qbchan) {
    $item = Get-Item $qbchan
    $lines.Add("Qbchan.dat: Size=$($item.Length) bytes, LastWriteTime=$($item.LastWriteTime)")
    $content = Get-Content $qbchan -ErrorAction SilentlyContinue

    # Grab [ChannelInfo] section
    $lines.Add("--- [ChannelInfo] Section ---")
    $inInfo = $false
    foreach ($line in $content) {
        if ($line -match '^\[ChannelInfo\]') { $inInfo = $true; continue }
        if ($inInfo -and $line -match '^\[') { break }
        if ($inInfo -and $line.Trim()) { $lines.Add("   $line") }
    }

    # Grab [Patch] section
    $lines.Add("--- [Patch] Section ---")
    $inPatch = $false
    foreach ($line in $content) {
        if ($line -match '^\[Patch\]') { $inPatch = $true; continue }
        if ($inPatch -and $line -match '^\[') { break }
        if ($inPatch -and $line.Trim()) { $lines.Add("   $line") }
    }

    # Grab [EPatch] section
    $lines.Add("--- [EPatch] Section ---")
    $inEPatch = $false
    foreach ($line in $content) {
        if ($line -match '^\[EPatch\]') { $inEPatch = $true; continue }
        if ($inEPatch -and $line -match '^\[') { break }
        if ($inEPatch -and $line.Trim()) { $lines.Add("   $line") }
    }
} else {
    $lines.Add("Qbchan.dat not found at $qbchan")
}

$lines.Add("")
$lines.Add("--- Files Modified in the Last 30 Minutes under ProgramData\Intuit ---")
$cutoff = (Get-Date).AddMinutes(-30)
$recentFiles = Get-ChildItem -Path "$env:ProgramData\Intuit" -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt $cutoff } |
    Sort-Object LastWriteTime -Descending

$lines.Add("Recent files found: $($recentFiles.Count)")
foreach ($rf in $recentFiles | Select-Object -First 30) {
    $lines.Add("   $($rf.LastWriteTime.ToString('HH:mm:ss')) | $($rf.Length) bytes | $($rf.FullName)")
}

$lines.Add("")
$lines.Add("--- Files Modified in the Last 30 Minutes under User Temp ---")
$recentTemp = Get-ChildItem -Path $env:TEMP -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt $cutoff -and ($_.FullName -match "Intuit|QuickBooks|qb") } |
    Sort-Object LastWriteTime -Descending

$lines.Add("Recent Temp Intuit/QB files found: $($recentTemp.Count)")
foreach ($tf in $recentTemp | Select-Object -First 20) {
    $lines.Add("   $($tf.LastWriteTime.ToString('HH:mm:ss')) | $($tf.Length) bytes | $($tf.FullName)")
}

$lines.Add("")
$lines | Out-File -FilePath $outFile -Encoding UTF8
Write-Host "Report written to: $outFile" -ForegroundColor Green
$lines | ForEach-Object { Write-Host $_ }
