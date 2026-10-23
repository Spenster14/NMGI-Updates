# Step 6.7 Diagnostics - Find where QuickBooks GUI reads the "LAST CHECKED" timestamp from
$scriptDir = $PSScriptRoot
$outFile = Join-Path $scriptDir "last_checked_origin.txt"

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("=== Finding 'LAST CHECKED' Origin in QuickBooks - $(Get-Date) - Host: $env:COMPUTERNAME ===")
$lines.Add("")

# 1. Search QBWUSER.INI across AppData\Local\Intuit
$iniFiles = Get-ChildItem -Path "$env:LOCALAPPDATA\Intuit", "$env:APPDATA\Intuit", "$env:ProgramData\Intuit" -Filter "*.ini" -Recurse -ErrorAction SilentlyContinue

$lines.Add("--- Searching INI files for 'Update' or 'LastRun' or timestamp ---")
foreach ($f in $iniFiles) {
    try {
        $matches = Select-String -Path $f.FullName -Pattern "(?i)(LastChecked|LastRun|1792699476|1792722083|QBUpdate|Patch)" -ErrorAction SilentlyContinue
        if ($matches) {
            $lines.Add("File: $($f.FullName)")
            foreach ($m in $matches | Select-Object -First 10) {
                $lines.Add("   Line $($m.LineNumber): $($m.Line.Trim())")
            }
        }
    } catch {}
}

# 2. Search Registry for LastChecked or Update timestamps
$lines.Add("")
$lines.Add("--- Searching Registry under HKCU:\Software\Intuit and HKLM:\Software\Intuit ---")
$regPaths = @(
    "HKCU:\Software\Intuit\QuickBooks",
    "HKLM:\Software\Intuit\QuickBooks",
    "HKLM:\Software\WOW6432Node\Intuit\QuickBooks"
)

foreach ($rp in $regPaths) {
    if (Test-Path $rp) {
        $keys = Get-ChildItem -Path $rp -Recurse -ErrorAction SilentlyContinue
        foreach ($k in $keys) {
            try {
                $vals = Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue
                foreach ($prop in $vals.PSObject.Properties) {
                    $strVal = "$($prop.Value)"
                    if ($strVal -match "1792699476|1792722083|03:04|08:19|08:51|09:21|01/23/2024" -or $prop.Name -match "(?i)(LastChecked|UpdateDate|LastUpdate)") {
                        $lines.Add("Key: $($k.Name) | Value: $($prop.Name) = $strVal")
                    }
                }
            } catch {}
        }
    }
}

$lines | Out-File -FilePath $outFile -Encoding UTF8
Write-Host "Report written to: $outFile" -ForegroundColor Green
$lines | ForEach-Object { Write-Host $_ }
