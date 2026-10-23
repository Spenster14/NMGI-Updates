# Step 6.2 - Runner to execute com_instantiate.ahk in both 64-bit and 32-bit AHK v2
$scriptDir = $PSScriptRoot
$ahkScript = Join-Path $scriptDir "com_instantiate.ahk"
$outFile   = Join-Path $scriptDir "com_instantiate.txt"

if (Test-Path $outFile) {
    Remove-Item $outFile -Force -ErrorAction SilentlyContinue
}

$ahkCandidates = @(
    @{ Name = "AHK 64-bit"; Path = "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" },
    @{ Name = "AHK 32-bit"; Path = "C:\Program Files\AutoHotkey\v2\AutoHotkey32.exe" },
    @{ Name = "AHK Default"; Path = "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" }
)

Write-Host "Running COM instantiation test for QuickBooks on $env:COMPUTERNAME..." -ForegroundColor Cyan

foreach ($cand in $ahkCandidates) {
    if (Test-Path $cand.Path) {
        Write-Host "--> Executing with $($cand.Name): $($cand.Path)" -ForegroundColor Yellow
        $p = Start-Process -FilePath $cand.Path -ArgumentList "`"$ahkScript`"" -WorkingDirectory $scriptDir -PassThru -Wait
        Write-Host "    Exited with code: $($p.ExitCode)"
    }
}

if (Test-Path $outFile) {
    Write-Host "`n=== Results from $outFile ===" -ForegroundColor Green
    Get-Content $outFile
} else {
    Write-Host "No output file created." -ForegroundColor Red
}
