param(
    [string]$Path = "",
    [switch]$All,
    [switch]$ChildWorker
)

# Step 6.7 - Multi-channel headless update loop with dynamic channel discovery
# Discovers active update channels from Qbchan.dat, monitors transfer progress,
# invokes agent.Install() when pending updates are ready, and unbinds cleanly.

$scriptDir = $PSScriptRoot
$outFile = Join-Path $scriptDir "update_all_report.txt"

$csharpCode = @"
using System;
using System.IO;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Reflection;
using System.Runtime.InteropServices;

#pragma warning disable 0219, 0414

[ComImport]
[Guid("d83a0652-b057-4f0f-a3fd-0bab62edc517")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IServiceManager
{
    void Services(out object pIServices);
    void Initialize([MarshalAs(UnmanagedType.U4)] uint ver, [MarshalAs(UnmanagedType.BStr)] string flavor, [MarshalAs(UnmanagedType.BStr)] string appPath);
    void InstallPending([MarshalAs(UnmanagedType.BStr)] string channelName, out int pVal);
    void ChannelDownloadDir([MarshalAs(UnmanagedType.BStr)] string channelName, [MarshalAs(UnmanagedType.BStr)] out string pVal);
    void error([MarshalAs(UnmanagedType.BStr)] string channelName, out int pError);
    void LockChannel([MarshalAs(UnmanagedType.BStr)] string channel, out int pLockNo);
    void UnlockChannel(int lockNo);
    void GetLastUpdate([MarshalAs(UnmanagedType.BStr)] string channelName, out int pVal);
    void GetHTMLDescriptionFile([MarshalAs(UnmanagedType.BStr)] string channelName, [MarshalAs(UnmanagedType.BStr)] out string pVal);
    void SetHTMLDescriptionFile([MarshalAs(UnmanagedType.BStr)] string channelName, [MarshalAs(UnmanagedType.BStr)] string path, int flag);
    void LockDirectory([MarshalAs(UnmanagedType.BStr)] string directory, out int pLockNo);
    void UnlockDirectory(int lockNo);
    void NewData([MarshalAs(UnmanagedType.BStr)] string channelName, [MarshalAs(UnmanagedType.BStr)] out string pDateString);
    void ResetChannel([MarshalAs(UnmanagedType.BStr)] string channelName);
    void ApplicationExit();
    void Install();
}

[ComImport]
[Guid("20a10bd2-8103-4a3c-bba3-cb123e989ef6")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IAgent
{
    void DoUpdateNow([MarshalAs(UnmanagedType.U4)] uint QBVersion, [MarshalAs(UnmanagedType.BStr)] string QBFlavor, [MarshalAs(UnmanagedType.BStr)] string QBAppPath, [MarshalAs(UnmanagedType.BStr)] string channelName, uint flags);
    void StopUpdating([MarshalAs(UnmanagedType.U4)] uint QBVersion, [MarshalAs(UnmanagedType.BStr)] string QBFlavor, [MarshalAs(UnmanagedType.BStr)] string QBAppPath, uint timeout);
    void Install([MarshalAs(UnmanagedType.U4)] uint QBVersion, [MarshalAs(UnmanagedType.BStr)] string QBFlavor, [MarshalAs(UnmanagedType.BStr)] string QBAppPath);
    void ResetChannel([MarshalAs(UnmanagedType.U4)] uint QBVersion, [MarshalAs(UnmanagedType.BStr)] string QBFlavor, [MarshalAs(UnmanagedType.BStr)] string QBAppPath, [MarshalAs(UnmanagedType.BStr)] string channelName);
    void ApplicationExit([MarshalAs(UnmanagedType.U4)] uint QBVersion, [MarshalAs(UnmanagedType.BStr)] string QBFlavor, [MarshalAs(UnmanagedType.BStr)] string QBAppPath);
    void InstallOfflineChannel([MarshalAs(UnmanagedType.U4)] uint QBVersion, [MarshalAs(UnmanagedType.BStr)] string QBFlavor, [MarshalAs(UnmanagedType.BStr)] string QBAppPath);
    void InstallPending2([MarshalAs(UnmanagedType.U4)] uint QBVersion, [MarshalAs(UnmanagedType.BStr)] string QBFlavor, [MarshalAs(UnmanagedType.BStr)] string QBAppPath, [MarshalAs(UnmanagedType.BStr)] string channelName, out int pending);
}

public class QBHeadlessEngine
{
    private static long GetDirectorySize(string dirPath)
    {
        if (string.IsNullOrEmpty(dirPath) || !Directory.Exists(dirPath)) return 0;
        try
        {
            long size = 0;
            var di = new DirectoryInfo(dirPath);
            foreach (var fi in di.GetFiles("*", SearchOption.AllDirectories))
            {
                size += fi.Length;
            }
            return size;
        }
        catch { return 0; }
    }

    public static string RunFullUpdate(string exePath, string[] channels, int channelTimeoutSeconds)
    {
        var output = new System.Text.StringBuilder();
        output.AppendLine("=== QuickBooks Headless Multi-Channel Updater ===");
        output.AppendLine("Target: " + exePath);

        object finder = null;
        object info = null;
        object rawMgr = null;
        object rawAgent = null;
        IServiceManager serviceMgr = null;
        IAgent agent = null;

        try
        {
            // 1. Resolve Instance Info
            Type finderType = Type.GetTypeFromProgID("QBInstanceFinder.InstalledInstanceFinder.1");
            if (finderType == null) throw new Exception("QBInstanceFinder.InstalledInstanceFinder.1 not found");
            finder = Activator.CreateInstance(finderType);

            info = finderType.InvokeMember("GetInstallationFromPath", BindingFlags.InvokeMethod, null, finder, new object[] { exePath });
            if (info == null) throw new Exception("GetInstallationFromPath returned null for: " + exePath);

            Type infoType = info.GetType();
            uint ver = Convert.ToUInt32(infoType.InvokeMember("majorVersion", BindingFlags.GetProperty, null, info, null));
            string flavor = Convert.ToString(infoType.InvokeMember("flavor", BindingFlags.GetProperty, null, info, null));
            string path = Convert.ToString(infoType.InvokeMember("exePath", BindingFlags.GetProperty, null, info, null));
            object rel = infoType.InvokeMember("releaseNumber", BindingFlags.GetProperty, null, info, null);

            output.AppendLine(string.Format("Resolved: Version={0}, Flavor={1}, Release={2}", ver, flavor, rel));
            output.AppendLine(string.Format("Engine Process: {0}-bit", IntPtr.Size * 8));

            // 2. Initialize ServiceManager
            Type mgrType = Type.GetTypeFromProgID("QBDServiceMgr2003.ServiceManager2003.1");
            if (mgrType == null) throw new Exception("QBDServiceMgr2003.ServiceManager2003.1 not found");
            rawMgr = Activator.CreateInstance(mgrType);
            serviceMgr = (IServiceManager)rawMgr;
            output.AppendLine(string.Format("Calling ServiceManager.Initialize({0}, \"{1}\", \"{2}\")...", ver, flavor, path));
            serviceMgr.Initialize(ver, flavor, path);
            output.AppendLine("ServiceManager bound successfully.");

            // 3. Initialize Agent
            Type agentType = Type.GetTypeFromProgID("QBDAgent2003.Agent2003.1");
            rawAgent = Activator.CreateInstance(agentType);
            agent = (IAgent)rawAgent;
            output.AppendLine("Agent2003 ready.");

            bool anyUpdatesInstalled = false;
            int totalPending = 0;

            // 4. Iterate Channels
            foreach (string ch in channels)
            {
                output.AppendLine(string.Format("\n>>> Checking Channel: {0} <<<", ch));
                DateTime chStart = DateTime.Now;

                // Check if already pending from prior run
                int existingPending = 0;
                try { serviceMgr.InstallPending(ch, out existingPending); } catch {}
                if (existingPending > 0)
                {
                    output.AppendLine(string.Format("   Channel '{0}' already has {1} update(s) pending install.", ch, existingPending));
                    totalPending += existingPending;
                    continue;
                }

                // Query download directory for this channel
                string chDownloadDir = null;
                try { serviceMgr.ChannelDownloadDir(ch, out chDownloadDir); } catch {}
                long lastDirBytes = GetDirectorySize(chDownloadDir);

                // Initiate download
                string taskError = null;
                Task.Factory.StartNew(() =>
                {
                    try { agent.DoUpdateNow(ver, flavor, path, ch, 0); }
                    catch (Exception exTask) { taskError = exTask.ToString(); }
                });

                // Monitor transfer patiently
                int waited = 0;
                int quietSeconds = 0;

                while (waited < channelTimeoutSeconds)
                {
                    System.Threading.Thread.Sleep(1000);
                    waited++;

                    if (taskError != null)
                    {
                        string firstLine = taskError.Split(new char[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries)[0];
                        output.AppendLine(string.Format("   (Channel notice: {0})", firstLine));
                        break;
                    }

                    // Check if pending updates appeared
                    int pending = 0;
                    try { serviceMgr.InstallPending(ch, out pending); } catch {}
                    if (pending > 0)
                    {
                        output.AppendLine(string.Format("   [Updates Ready @ {0}s] Channel '{1}' finished downloading ({2} pending).", waited, ch, pending));
                        totalPending += pending;
                        break;
                    }

                    // Check channel error code
                    int chErr = 0;
                    try { serviceMgr.error(ch, out chErr); } catch {}
                    if (chErr != 0)
                    {
                        output.AppendLine(string.Format("   [serviceMgr.error @ {0}s] Channel '{1}' error code: {2}", waited, ch, chErr));
                    }

                    // Track directory byte growth
                    long currentDirBytes = GetDirectorySize(chDownloadDir);
                    if (currentDirBytes > lastDirBytes)
                    {
                        output.AppendLine(string.Format("   [Transferring @ {0}s] Channel '{1}': {2:0.0} MB downloaded...", waited, ch, currentDirBytes / (1024.0 * 1024.0)));
                        lastDirBytes = currentDirBytes;
                        quietSeconds = 0;
                    }
                    else
                    {
                        quietSeconds++;
                        // If no new bytes transferred for 8 seconds after initial 4 seconds, channel check is complete
                        if (waited >= 4 && quietSeconds >= 8)
                        {
                            break;
                        }
                    }
                }

                int finalPending = 0;
                try { serviceMgr.InstallPending(ch, out finalPending); } catch {}
                int finalErr = 0;
                try { serviceMgr.error(ch, out finalErr); } catch {}
                output.AppendLine(string.Format("   Channel '{0}' finished in {1:0.0}s. (Pending={2}, Error={3})", ch, (DateTime.Now - chStart).TotalSeconds, finalPending, finalErr));
            }

            // 5. If updates were downloaded/pending, trigger Install()
            if (totalPending > 0)
            {
                output.AppendLine(string.Format("\nInstalling {0} pending update(s) headlessly...", totalPending));
                try
                {
                    agent.Install(ver, flavor, path);
                    anyUpdatesInstalled = true;
                    output.AppendLine("   [SUCCESS] agent.Install() executed successfully!");
                }
                catch (Exception exInst)
                {
                    output.AppendLine("   (agent.Install notice: " + exInst.Message + ")");
                }
            }

            // 6. Cleanup
            try { serviceMgr.ApplicationExit(); } catch {}

            output.AppendLine("\n------------------------------------------------");
            if (anyUpdatesInstalled)
            {
                output.AppendLine("FINAL STATUS:  - Updates installed");
            }
            else
            {
                output.AppendLine("FINAL STATUS:  - No updates");
            }
        }
        catch (Exception ex)
        {
            string msg = ex.InnerException != null ? ex.InnerException.Message : ex.Message;
            output.AppendLine("\nFINAL STATUS:  - Error (" + msg + ")");
        }
        finally
        {
            if (rawAgent != null) try { Marshal.ReleaseComObject(rawAgent); } catch {}
            if (rawMgr != null) try { Marshal.ReleaseComObject(rawMgr); } catch {}
            if (info != null) try { Marshal.ReleaseComObject(info); } catch {}
            if (finder != null) try { Marshal.ReleaseComObject(finder); } catch {}
        }

        return output.ToString();
    }
}
"@

try {
    Add-Type -TypeDefinition $csharpCode -Language CSharp
} catch {
    Write-Warning "QBHeadlessEngine notice: $($_.Exception.Message)"
}

function Get-ActiveQBChannels($targetExe) {
    # Resolve target ProgramData folder from executable path
    $parent = Split-Path -Parent $targetExe
    $dirName = Split-Path -Leaf $parent
    $progData = Join-Path $env:ProgramData "Intuit\$dirName"
    $chanFile = Join-Path $progData "Components\QBUpdate\Qbchan.dat"

    # Known update channel targets supported by IAgent.DoUpdateNow
    $validTargets = @("EPatch", "SPatch", "Patch", "NewFeatures", "Payroll", "FedForms", "StateForms", "Help0", "Guide", "Belacct", "Accountant", "Pro00", "Bel00")

    $channels = @()
    if (Test-Path $chanFile) {
        $content = Get-Content $chanFile -ErrorAction SilentlyContinue
        $currentSection = ""
        $isActive = $false
        $isHidden = $false

        foreach ($line in $content) {
            $line = $line.Trim()
            if ($line -match '^\[(.*)\]$') {
                if ($currentSection -and $isActive -and -not $isHidden) {
                    if ($validTargets -contains $currentSection) {
                        $channels += $currentSection
                    }
                }
                $currentSection = $matches[1]
                $isActive = $false
                $isHidden = $false
            } elseif ($line -match '^ActiveEnabled\s*=\s*1') {
                $isActive = $true
            } elseif ($line -match '^HiddenEnabled\s*=\s*1') {
                $isHidden = $true
            }
        }
        if ($currentSection -and $isActive -and -not $isHidden) {
            if ($validTargets -contains $currentSection) {
                $channels += $currentSection
            }
        }
    }

    # If no channels detected from Qbchan.dat, use prioritized defaults based on edition
    if ($channels.Count -eq 0) {
        if ($targetExe -match "Enterprise") {
            $channels = @("EPatch", "NewFeatures", "Belacct")
        } else {
            $channels = @("SPatch", "Patch", "NewFeatures", "Accountant")
        }
    }

    return $channels
}

$candidates = @(
    "C:\Program Files\Intuit\QuickBooks 2024\qbw.exe",
    "C:\Program Files\Intuit\QuickBooks Enterprise Solutions 24.0\qbw.exe",
    "C:\Program Files\Intuit\QuickBooks 2023\qbw.exe",
    "C:\Program Files\Intuit\QuickBooks Enterprise Solutions 23.0\qbw.exe",
    "C:\Program Files\Intuit\QuickBooks 2022\qbw.exe",
    "C:\Program Files\Intuit\QuickBooks Enterprise Solutions 22.0\qbw.exe",
    "C:\Program Files (x86)\Intuit\QuickBooks 2021\qbw32.exe",
    "C:\Program Files (x86)\Intuit\QuickBooks Enterprise Solutions 21.0\qbw32.exe"
)

$targets = @()
if ($Path) {
    if (Test-Path $Path) {
        # If user passed a flavor launcher (e.g. QBW32PremierAccountant.exe), resolve to underlying qbw32.exe or qbw.exe
        $dir = Split-Path -Parent $Path
        $leaf = Split-Path -Leaf $Path
        if ($leaf -ne "qbw.exe" -and $leaf -ne "qbw32.exe") {
            $qbw32 = Join-Path $dir "qbw32.exe"
            $qbw = Join-Path $dir "qbw.exe"
            if (Test-Path $qbw32) {
                Write-Host "Auto-resolving launcher '$leaf' to core engine: $qbw32" -ForegroundColor DarkCyan
                $Path = $qbw32
            } elseif (Test-Path $qbw) {
                Write-Host "Auto-resolving launcher '$leaf' to core engine: $qbw" -ForegroundColor DarkCyan
                $Path = $qbw
            }
        }
        $targets += $Path
    }
    else { Write-Host "Specified path not found: $Path" -ForegroundColor Red; exit 1 }
} elseif ($All) {
    foreach ($c in $candidates) {
        if (Test-Path $c) { $targets += $c }
    }
} else {
    # Default: if neither -Path nor -All is given, default to updating all found
    foreach ($c in $candidates) {
        if (Test-Path $c) { $targets += $c }
    }
}

if ($targets.Count -eq 0) {
    Write-Host "No QuickBooks executables found on this machine." -ForegroundColor Red
    exit 0
}

if ($ChildWorker) {
    # Child worker called for 32-bit architecture dispatch
    $activeChannels = Get-ActiveQBChannels $targets[0]
    $subReport = [QBHeadlessEngine]::RunFullUpdate($targets[0], $activeChannels, 180)
    Write-Output $subReport
    exit 0
}

Write-Host "Found $($targets.Count) QuickBooks installation(s) to process:" -ForegroundColor Cyan
foreach ($t in $targets) { Write-Host "   -> $t" }

$fullReport = New-Object System.Text.StringBuilder

foreach ($targetExe in $targets) {
    Write-Host "`n========================================================" -ForegroundColor Yellow
    Write-Host "Processing: $targetExe" -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow

    # Check bitness compatibility
    $is32BitTarget = ($targetExe -match "\(x86\)") -or ($targetExe -match "qbw32\.exe")
    $is64BitProcess = [IntPtr]::Size -eq 8
    $wow64Ps = "$env:SystemRoot\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"

    if ($is32BitTarget -and $is64BitProcess -and (Test-Path $wow64Ps)) {
        Write-Host "Target is 32-bit QuickBooks (2021 or older); dispatching to 32-bit PowerShell engine..." -ForegroundColor Magenta
        $subReport = & $wow64Ps -ExecutionPolicy Bypass -File $PSCommandPath -Path $targetExe -ChildWorker
        $fullReport.AppendLine($subReport)
        Write-Host $subReport
        continue
    }

    # Discover active channels for this target edition
    $activeChannels = Get-ActiveQBChannels $targetExe
    Write-Host "Discovered $($activeChannels.Count) active update channels: $($activeChannels -join ', ')" -ForegroundColor Cyan

    # Run full update with patient download monitoring (180s max timeout per channel)
    $subReport = [QBHeadlessEngine]::RunFullUpdate($targetExe, $activeChannels, 180)
    $fullReport.AppendLine($subReport)
    Write-Host $subReport
}

$fullReport.ToString() | Out-File -FilePath $outFile -Encoding UTF8
Write-Host "`nAll $($targets.Count) installation(s) completed. Report written to $outFile" -ForegroundColor Green
