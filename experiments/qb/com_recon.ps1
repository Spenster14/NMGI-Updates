# Step 6.1 - READ-ONLY COM recon for Intuit QuickBooks update objects.
# Scans CLSIDs in both registry views (64-bit / 32-bit) and reports matches.
$out = Join-Path $PSScriptRoot 'com_recon.txt'
$pattern = 'qbagent|qbdagent|servicemgr|servicemanager|qbinstance|intuit|quickbooks'
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("QB COM recon - $(Get-Date) - Host $env:COMPUTERNAME")

foreach ($view in 'Registry64','Registry32') {
    $lines.Add("")
    $lines.Add("=== View: $view ===")
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', $view)
    $clsid = $base.OpenSubKey('SOFTWARE\Classes\CLSID')
    if (-not $clsid) { $lines.Add("(no CLSID key)"); continue }
    foreach ($name in $clsid.GetSubKeyNames()) {
        $k = $clsid.OpenSubKey($name)
        if (-not $k) { continue }
        $desc  = $k.GetValue('')
        $prog  = $null; $pk = $k.OpenSubKey('ProgID'); if ($pk) { $prog = $pk.GetValue('') }
        $inproc = $null; $ik = $k.OpenSubKey('InprocServer32'); if ($ik) { $inproc = $ik.GetValue('') }
        $local  = $null; $lk = $k.OpenSubKey('LocalServer32');  if ($lk) { $local  = $lk.GetValue('') }
        $tl = $null; $tk = $k.OpenSubKey('TypeLib'); if ($tk) { $tl = $tk.GetValue('') }
        $blob = "$desc|$prog|$inproc|$local"
        if ($blob -match $pattern) {
            $lines.Add("CLSID $name")
            $lines.Add("   Desc: $desc")
            $lines.Add("   ProgID: $prog")
            if ($inproc) { $lines.Add("   InprocServer32: $inproc") }
            if ($local)  { $lines.Add("   LocalServer32: $local") }
            if ($tl)     { $lines.Add("   TypeLib: $tl") }
        }
    }
}

$lines.Add("")
$lines.Add("=== QuickBooks install folders ===")
foreach ($p in "$env:ProgramFiles\Intuit", "${env:ProgramFiles(x86)}\Intuit", "$env:ProgramData\Intuit", "${env:CommonProgramFiles(x86)}\Intuit") {
    if (Test-Path $p) {
        $lines.Add($p)
        Get-ChildItem $p -Directory -ErrorAction SilentlyContinue | ForEach-Object { $lines.Add("   $($_.Name)") }
    } else { $lines.Add("$p (missing)") }
}

$lines | Set-Content -Path $out -Encoding UTF8
Write-Output "Wrote $out ($($lines.Count) lines)"
