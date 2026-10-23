param(
    [string]$Path = "",
    [switch]$All
)

# Step 6.7 - Multi-channel headless update loop across all patch channels
# Iterates through maintenance channels ("Patch", "EPatch", "SPatch", "FPatch"), monitors progress,
# calls agent.Install() if updates are downloaded/pending, and returns standardized status.

$scriptDir = $PSScriptRoot
$outFile = Join-Path $scriptDir "update_all_report.txt"

$csharpCode = @"
using System;
using System.IO;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Reflection;
using System.Runtime.InteropServices;

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

            // 2. Initialize ServiceManager
            Type mgrType = Type.GetTypeFromProgID("QBDServiceMgr2003.ServiceManager2003.1");
            rawMgr = Activator.CreateInstance(mgrType);
            serviceMgr = (IServiceManager)rawMgr;
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
                output.AppendLine(string.Format("\n>>> Processing Channel: {0} <<<", ch));
                DateTime chStart = DateTime.Now;

                Task updateTask = Task.Factory.StartNew(() =>
                {
                    try { agent.DoUpdateNow(ver, flavor, path, ch, 0); }
                    catch {}
                });

                // Wait for channel completion or timeout
                int waited = 0;
                while (waited < channelTimeoutSeconds)
                {
                    System.Threading.Thread.Sleep(1000);
                    waited++;

                    // Check if pending updates appeared
                    int pending = 0;
                    try { serviceMgr.InstallPending(ch, out pending); } catch {}
                    if (pending > 0)
                    {
                        output.AppendLine(string.Format("   [Pending Detected @ {0}s] Channel '{1}' has updates pending ({2})", waited, ch, pending));
                        totalPending += pending;
                        break;
                    }

                    // Check if update task finished early
                    if (updateTask.IsCompleted)
                    {
                        output.AppendLine(string.Format("   Channel check completed at {0}s.", waited));
                        break;
                    }
                }

                // Stop updating for this channel
                try { agent.StopUpdating(ver, flavor, path, 0); } catch {}
                output.AppendLine(string.Format("   Channel '{0}' finished in {1:0.0}s.", ch, (DateTime.Now - chStart).TotalSeconds));
            }

            // 5. If updates were downloaded/pending, trigger Install()
            if (totalPending > 0)
            {
                output.AppendLine(string.Format("\nInstalling {0} pending update(s)...", totalPending));
                try
                {
                    agent.Install(ver, flavor, path);
                    anyUpdatesInstalled = true;
                    output.AppendLine("   [SUCCESS] agent.Install() completed!");
                }
                catch (Exception exInst)
                {
                    output.AppendLine("   (Install notice: " + exInst.Message + ")");
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

$patchChannels = @("Patch", "EPatch", "SPatch", "FPatch")

if ($targets.Count -eq 0) {
    Write-Host "No QuickBooks executables found on this machine." -ForegroundColor Red
    exit 0
}

Write-Host "Found $($targets.Count) QuickBooks installation(s) to process:" -ForegroundColor Cyan
foreach ($t in $targets) { Write-Host "   -> $t" }

$fullReport = New-Object System.Text.StringBuilder

foreach ($targetExe in $targets) {
    Write-Host "`n========================================================" -ForegroundColor Yellow
    Write-Host "Processing: $targetExe" -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow

    # Run through the 4 patch channels with 15-second timeout per channel
    $subReport = [QBHeadlessEngine]::RunFullUpdate($targetExe, $patchChannels, 15)
    $fullReport.AppendLine($subReport)
    Write-Host $subReport
}

$fullReport.ToString() | Out-File -FilePath $outFile -Encoding UTF8
Write-Host "`nAll $($targets.Count) installation(s) completed. Report written to $outFile" -ForegroundColor Green

