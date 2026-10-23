# Step 6.4 - Locate qbchan.dat, channel.log, and inspect InstalledInstanceInfo for each QB
# READ-ONLY: Gathers channel list and exact parameters needed for headless update calls.

$scriptDir = $PSScriptRoot
$outFile = Join-Path $scriptDir "channels_report.txt"

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("=== QuickBooks Channel & Instance Discovery - $(Get-Date) - Host: $env:COMPUTERNAME ===")
$lines.Add("")

# Part 1: Query InstalledInstanceInfo via QBInstanceFinder for each installed qbw.exe
$lines.Add("--- Part 1: Installed QuickBooks Instances (via QBInstanceFinder) ---")

$finderType = [Type]::GetTypeFromProgID("QBInstanceFinder.InstalledInstanceFinder.1")
$finder = $null
if ($finderType) {
    try { $finder = [Activator]::CreateInstance($finderType) } catch {}
}

$qbExeCandidates = @(
    "C:\Program Files\Intuit\QuickBooks 2024\qbw.exe",
    "C:\Program Files\Intuit\QuickBooks Enterprise Solutions 24.0\qbw.exe",
    "C:\Program Files\Intuit\QuickBooks 2023\qbw.exe",
    "C:\Program Files\Intuit\QuickBooks Enterprise Solutions 23.0\qbw.exe",
    "C:\Program Files\Intuit\QuickBooks 2022\qbw.exe",
    "C:\Program Files\Intuit\QuickBooks Enterprise Solutions 22.0\qbw.exe",
    "C:\Program Files (x86)\Intuit\QuickBooks 2021\qbw32.exe",
    "C:\Program Files (x86)\Intuit\QuickBooks Enterprise Solutions 21.0\qbw32.exe"
)

foreach ($exe in $qbExeCandidates) {
    if (Test-Path $exe) {
        $lines.Add("Found Exe: $exe")
        if ($finder) {
            try {
                $info = $finder.GetInstallationFromPath($exe)
                if ($info) {
                    $ver    = $info.majorVersion
                    $flavor = $info.flavor
                    $flavId = $info.flavorID
                    $path   = $info.exePath
                    $rel    = $info.releaseNumber
                    $run    = $info.IsRunning()
                    $lines.Add("   -> majorVersion : $ver")
                    $lines.Add("   -> flavor       : $flavor (flavorID=$flavId)")
                    $lines.Add("   -> exePath      : $path")
                    $lines.Add("   -> releaseNum   : $rel")
                    $lines.Add("   -> isRunning    : $run")
                    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($info) | Out-Null
                }
            } catch {
                $lines.Add("   -> Error querying GetInstallationFromPath: $($_.Exception.Message)")
            }
        }
    }
}

if ($finder) {
    try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($finder) | Out-Null } catch {}
}

$lines.Add("")
$lines.Add("--- Part 2: Search for qbchan.dat and channel.log files ---")

$searchRoots = @(
    "$env:ProgramData\Intuit",
    "$env:ProgramFiles\Common Files\Intuit\QuickBooks\QBUpdate",
    "${env:ProgramFiles(x86)}\Common Files\Intuit\QuickBooks\QBUpdate"
)

$chanFiles = @()
$logFiles  = @()

foreach ($root in $searchRoots) {
    if (Test-Path $root) {
        Get-ChildItem -Path $root -Filter "qbchan.dat" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $chanFiles += $_.FullName }
        Get-ChildItem -Path $root -Filter "channel.log" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $logFiles += $_.FullName }
    }
}

$lines.Add("qbchan.dat files found: $($chanFiles.Count)")
foreach ($cf in $chanFiles) {
    $lines.Add("")
    $lines.Add("File: $cf (Size: $( (Get-Item $cf).Length ) bytes)")
    try {
        # qbchan.dat is typically an INI or text format with channel names
        $content = Get-Content $cf -Raw -ErrorAction SilentlyContinue
        # Show sections or lines containing channel targets
        $rawLines = Get-Content $cf -ErrorAction SilentlyContinue
        $lines.Add("   First 25 lines:")
        $rawLines | Select-Object -First 25 | ForEach-Object { $lines.Add("      $_") }
    } catch {
        $lines.Add("   Error reading: $($_.Exception.Message)")
    }
}

$lines.Add("")
$lines.Add("channel.log files found: $($logFiles.Count)")
foreach ($lf in $logFiles) {
    $item = Get-Item $lf
    $lines.Add("")
    $lines.Add("File: $lf (Size: $($item.Length) bytes, LastWrite: $($item.LastWriteTime))")
    try {
        $tail = Get-Content $lf -Tail 30 -ErrorAction SilentlyContinue
        $lines.Add("   Last 30 lines:")
        foreach ($t in $tail) { $lines.Add("      $t") }
    } catch {
        $lines.Add("   Error reading: $($_.Exception.Message)")
    }
}

$lines.Add("")
$lines | Out-File -FilePath $outFile -Encoding UTF8
Write-Host "Wrote report to: $outFile ($($lines.Count) lines)" -ForegroundColor Green

# Output to console
$lines | Select-Object -First 100 | ForEach-Object { Write-Host $_ }
if ($lines.Count -gt 100) {
    Write-Host "... (Output truncated in console, full report in $outFile) ..." -ForegroundColor Yellow
}
