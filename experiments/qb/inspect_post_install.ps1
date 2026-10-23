# Step 6.7 Post-Install Forensic Inspection
# Dumps what was installed by the manual update in QB Enterprise 21.0
$scriptDir = $PSScriptRoot
$outFile = Join-Path $scriptDir "post_install_report.txt"

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("=== Post-Install Forensic Inspection - $(Get-Date) - Host: $env:COMPUTERNAME ===")
$lines.Add("")

$qbPath = "$env:ProgramData\Intuit\QuickBooks Enterprise Solutions 21.0"

# 1. Install.log
$installLog = Join-Path $qbPath "Components\QBUpdate\Log\Install.log"
if (Test-Path $installLog) {
    $item = Get-Item $installLog
    $lines.Add("--- Install.log (Size=$($item.Length) bytes, LastWriteTime=$($item.LastWriteTime)) ---")
    $tail = Get-Content $installLog -Tail 50 -ErrorAction SilentlyContinue
    foreach ($l in $tail) { $lines.Add("   $l") }
} else {
    $lines.Add("Install.log not found at $installLog")
}

# 2. Check for other logs under QBUpdate\Log
$otherLogs = Get-ChildItem -Path "$qbPath\Components\QBUpdate" -Filter "*.log" -Recurse -ErrorAction SilentlyContinue
$lines.Add("")
$lines.Add("--- Other QBUpdate Logs ---")
foreach ($ol in $otherLogs) {
    $lines.Add("Log: $($ol.FullName) (Size=$($ol.Length), LastWrite=$($ol.LastWriteTime))")
}

# 3. Qbchan.dat sections that changed
$lines.Add("")
$lines.Add("--- Sections in Qbchan.dat with Recent Changes or Specific Channels ---")
$chanFile = Join-Path $qbPath "Components\QBUpdate\Qbchan.dat"
if (Test-Path $chanFile) {
    $item = Get-Item $chanFile
    $lines.Add("Qbchan.dat: Size=$($item.Length) bytes, LastWriteTime=$($item.LastWriteTime)")
    $content = Get-Content $chanFile -ErrorAction SilentlyContinue

    $currentSection = ""
    $currentLines = @()
    $interestingSections = @("ChannelInfo", "NewFeatures", "EPatch", "Patch", "SPatch", "FPatch", "FSPUpgrade", "SUpgrade", "Belacct")

    foreach ($line in $content) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\[(.*)\]$') {
            if ($interestingSections -contains $currentSection) {
                $lines.Add("[$currentSection]")
                foreach ($cl in $currentLines) { $lines.Add("   $cl") }
                $lines.Add("")
            }
            $currentSection = $matches[1]
            $currentLines = @()
        } else {
            if ($trimmed) { $currentLines += $trimmed }
        }
    }
    if ($interestingSections -contains $currentSection) {
        $lines.Add("[$currentSection]")
        foreach ($cl in $currentLines) { $lines.Add("   $cl") }
        $lines.Add("")
    }
}

# 4. Files modified in last 45 minutes under Components
$lines.Add("")
$lines.Add("--- Files Modified in Last 45 Minutes under Components ---")
$cutoff = (Get-Date).AddMinutes(-45)
$modFiles = Get-ChildItem -Path "$qbPath\Components" -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt $cutoff } |
    Sort-Object LastWriteTime -Descending

$lines.Add("Total files modified: $($modFiles.Count)")
foreach ($mf in $modFiles | Select-Object -First 30) {
    $lines.Add("   $($mf.LastWriteTime.ToString('HH:mm:ss')) | $($mf.Length) bytes | $($mf.FullName)")
}

$lines | Out-File -FilePath $outFile -Encoding UTF8
Write-Host "Wrote report to: $outFile" -ForegroundColor Green
$lines | ForEach-Object { Write-Host $_ }
