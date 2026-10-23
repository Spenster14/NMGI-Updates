param(
    [switch]$Child
)

$scriptDir = $PSScriptRoot
$outFile = Join-Path $scriptDir "com_instantiate.txt"

if (-not $Child) {
    if (Test-Path $outFile) { Remove-Item $outFile -Force -ErrorAction SilentlyContinue }
}

$arch = if ([IntPtr]::Size -eq 8) { "64-bit" } else { "32-bit" }
$header = "=== PowerShell ($arch) on $env:COMPUTERNAME at $(Get-Date) ==="

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add($header)

$targets = @(
    @{ Name = "Agent2003";               ProgId = "QBDAgent2003.Agent2003.1";              Clsid = "{20A10BD4-0FF4-45e8-87EF-D2708E99CEAA}" },
    @{ Name = "ChNotify";                ProgId = "QBDAgent.ChNotify.1";                   Clsid = "{20A10BD7-FF8F-4eb0-9754-7F9641B35BB5}" },
    @{ Name = "ServiceManager2003";      ProgId = "QBDServiceMgr2003.ServiceManager2003.1"; Clsid = "{D83A0655-59E2-44a5-B1F0-CB07B9B972F2}" },
    @{ Name = "Services2003";            ProgId = "QBDServiceMgr2003.Services2003.1";       Clsid = "{D83A0656-565B-47b1-A1BC-42F700061A72}" },
    @{ Name = "InstalledInstanceFinder"; ProgId = "QBInstanceFinder.InstalledInstanceFinder.1"; Clsid = "{77AD5847-AE1B-4193-9F15-6E9B2D811E4D}" },
    @{ Name = "InstanceFinderUtil";      ProgId = "QBInstanceFinder.InstanceFinderUtil.1";       Clsid = "{7A669A0C-0813-4bf1-A723-26B79C5E9DDC}" }
)

foreach ($t in $targets) {
    $name = $t.Name
    $prog = $t.ProgId
    $clsid = $t.Clsid

    $type = [Type]::GetTypeFromProgID($prog)
    $source = "ProgID $prog"
    if (-not $type) {
        $type = [Type]::GetTypeFromCLSID([Guid]::Parse($clsid))
        $source = "CLSID $clsid"
    }

    if (-not $type) {
        $lines.Add("$name : FAIL (Neither ProgID nor CLSID resolved to a Type)")
        continue
    }

    try {
        $obj = [Activator]::CreateInstance($type)
        if ($obj) {
            $lines.Add("$name : OK via $source")
            try {
                $members = $obj | Get-Member -MemberType Method, Property | ForEach-Object { "      " + $_.Definition }
                if ($members) {
                    $lines.Add("   Members:")
                    foreach ($m in $members) { $lines.Add($m) }
                }
            } catch {
                $lines.Add("   (Unable to inspect members: $($_.Exception.Message))")
            }
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
        } else {
            $lines.Add("$name : FAIL (CreateInstance returned null)")
        }
    } catch {
        $lines.Add("$name : FAIL via $source -> $($_.Exception.Message)")
    }
}

$lines.Add("")
$lines | Out-File -FilePath $outFile -Append -Encoding UTF8

# If running as 64-bit parent, automatically invoke 32-bit PowerShell to test both views
if (-not $Child -and [IntPtr]::Size -eq 8) {
    $ps32 = "$env:WINDIR\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $ps32) {
        Start-Process -FilePath $ps32 -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`" -Child" -WorkingDirectory $scriptDir -Wait
    }
}

if (-not $Child) {
    Get-Content $outFile
}
