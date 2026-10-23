# Step 6.7 Diagnostics - Inspect exact channel names and logs for QB Enterprise 21.0 vs QB 2024
$scriptDir = $PSScriptRoot
$outFile = Join-Path $scriptDir "channels_detail_report.txt"

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("=== QuickBooks Channel Detail Inspection - $(Get-Date) - Host: $env:COMPUTERNAME ===")
$lines.Add("")

$targets = @(
    @{ Name = "QB Enterprise 21.0"; Path = "$env:ProgramData\Intuit\QuickBooks Enterprise Solutions 21.0" },
    @{ Name = "QB 2021";            Path = "$env:ProgramData\Intuit\QuickBooks 2021" },
    @{ Name = "QB 2024";            Path = "$env:ProgramData\Intuit\QuickBooks 2024" }
)

foreach ($t in $targets) {
    $lines.Add("==================================================================")
    $lines.Add("Target: $($t.Name) ($($t.Path))")
    $lines.Add("==================================================================")

    $chanFile = Join-Path $t.Path "Components\QBUpdate\Qbchan.dat"
    if (Test-Path $chanFile) {
        $item = Get-Item $chanFile
        $lines.Add("Qbchan.dat: Size=$($item.Length) bytes, LastWriteTime=$($item.LastWriteTime)")
        
        $content = Get-Content $chanFile -ErrorAction SilentlyContinue
        $sections = @()
        $currentSection = ""
        $currentProps = @{}

        foreach ($line in $content) {
            $line = $line.Trim()
            if ($line -match '^\[(.*)\]$') {
                if ($currentSection) {
                    $sections += [PSCustomObject]@{
                        Section = $currentSection
                        Target  = $currentProps["UpdateTarget"]
                        Source  = $currentProps["SourceURL"]
                        Status  = $currentProps["Status"]
                        LastRun = $currentProps["LastRun"]
                    }
                }
                $currentSection = $matches[1]
                $currentProps = @{}
            } elseif ($line -match '^([^=]+)=(.*)$') {
                $currentProps[$matches[1].Trim()] = $matches[2].Trim()
            }
        }
        if ($currentSection) {
            $sections += [PSCustomObject]@{
                Section = $currentSection
                Target  = $currentProps["UpdateTarget"]
                Source  = $currentProps["SourceURL"]
                Status  = $currentProps["Status"]
                LastRun = $currentProps["LastRun"]
            }
        }

        $lines.Add("Channels found in Qbchan.dat: $($sections.Count)")
        foreach ($s in $sections) {
            $lines.Add(string.Format("   [{0}] Target='{1}' Status='{2}' LastRun='{3}' Source='{4}'", $s.Section, $s.Target, $s.Status, $s.LastRun, $s.Source))
        }
    } else {
        $lines.Add("Qbchan.dat not found at $chanFile")
    }

    $lines.Add("")
    $logFile = Join-Path $t.Path "Components\QBUpdate\channel.log"
    if (Test-Path $logFile) {
        $lItem = Get-Item $logFile
        $lines.Add("channel.log: Size=$($lItem.Length) bytes, LastWriteTime=$($lItem.LastWriteTime)")
        $tail = Get-Content $logFile -Tail 25 -ErrorAction SilentlyContinue
        $lines.Add("   Last 25 lines of channel.log:")
        foreach ($tl in $tail) { $lines.Add("      $tl") }
    } else {
        $lines.Add("channel.log not found at $logFile")
    }
    $lines.Add("")
}

$lines | Out-File -FilePath $outFile -Encoding UTF8
Write-Host "Wrote report to: $outFile" -ForegroundColor Green
$lines | ForEach-Object { Write-Host $_ }
