# Step 6.6 - Real update test on ONE channel ("Patch")
# Backs up Components first, initializes ServiceManager, runs IAgent.DoUpdateNow on background thread,
# monitors log/file activity, and cleans up with StopUpdating and ApplicationExit.

$scriptDir = $PSScriptRoot
$outFile = Join-Path $scriptDir "update_one_report.txt"

# 1. Backup Components folder for safety
$compDir = "C:\ProgramData\Intuit\QuickBooks 2024\Components"
$compBak = "C:\ProgramData\Intuit\QuickBooks 2024\Components.bak_step66"

if (Test-Path $compDir) {
    if (-not (Test-Path $compBak)) {
        Write-Host "Creating safety backup of Components folder..." -ForegroundColor Cyan
        Copy-Item -Path $compDir -Destination $compBak -Recurse -Force
        Write-Host "   Backup created at: $compBak" -ForegroundColor Green
    } else {
        Write-Host "Backup already exists at: $compBak" -ForegroundColor Yellow
    }
}

$csharpCode = @"
using System;
using System.IO;
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

public class QBUpdateTester
{
    public static string RunUpdateTest(string exePath, uint year, string flavor, string channel, int maxWaitSeconds)
    {
        var output = new System.Text.StringBuilder();
        output.AppendLine("=== Testing Single-Channel Update for: " + exePath + " ===");
        output.AppendLine(string.Format("Target: Year={0}, Flavor={1}, Channel={2}", year, flavor, channel));

        object rawMgr = null;
        object rawAgent = null;
        IServiceManager serviceMgr = null;
        IAgent agent = null;

        try
        {
            // 1. Initialize ServiceManager
            Type mgrType = Type.GetTypeFromProgID("QBDServiceMgr2003.ServiceManager2003.1");
            rawMgr = Activator.CreateInstance(mgrType);
            serviceMgr = (IServiceManager)rawMgr;
            output.AppendLine("Initializing ServiceManager...");
            serviceMgr.Initialize(year, flavor, exePath);
            output.AppendLine("   [OK] ServiceManager.Initialize succeeded.");

            // 2. Instantiate Agent
            Type agentType = Type.GetTypeFromProgID("QBDAgent2003.Agent2003.1");
            rawAgent = Activator.CreateInstance(agentType);
            agent = (IAgent)rawAgent;
            output.AppendLine("   [OK] Agent instantiated.");

            // 3. Start DoUpdateNow on a background thread
            output.AppendLine(string.Format("Triggering DoUpdateNow on background Task for channel '{0}'...", channel));
            DateTime startTime = DateTime.Now;
            bool taskFailed = false;
            string taskError = "";

            Task updateTask = Task.Factory.StartNew(() =>
            {
                try
                {
                    agent.DoUpdateNow(year, flavor, exePath, channel, 0);
                }
                catch (Exception ex)
                {
                    taskFailed = true;
                    taskError = ex.Message;
                }
            });

            output.AppendLine("Background update Task started.");

            // 4. Monitor loop
            string qbDataDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "Intuit", "QuickBooks " + (year == 34 ? "2024" : year.ToString()));
            string logFile = Path.Combine(qbDataDir, "channel.log");
            string compLogFile = Path.Combine(qbDataDir, "Components", "channel.log");

            output.AppendLine(string.Format("Monitoring log files for up to {0} seconds...", maxWaitSeconds));

            long lastLogLength = 0;
            string activeLog = null;

            for (int sec = 0; sec < maxWaitSeconds; sec++)
            {
                System.Threading.Thread.Sleep(1000);

                if (taskFailed)
                {
                    output.AppendLine("   [TASK ERROR] DoUpdateNow threw: " + taskError);
                    break;
                }

                // Check for log file presence
                if (activeLog == null)
                {
                    if (File.Exists(logFile)) activeLog = logFile;
                    else if (File.Exists(compLogFile)) activeLog = compLogFile;
                }

                if (activeLog != null && File.Exists(activeLog))
                {
                    try
                    {
                        var fi = new FileInfo(activeLog);
                        if (fi.Length > lastLogLength)
                        {
                            using (var fs = new FileStream(activeLog, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                            {
                                fs.Seek(lastLogLength, SeekOrigin.Begin);
                                using (var reader = new StreamReader(fs))
                                {
                                    string newContent = reader.ReadToEnd();
                                    output.AppendLine(string.Format("   [Log +{0}s]: {1}", sec, newContent.TrimEnd()));

                                    if (newContent.Contains("Installing 0") || newContent.Contains("ChannelUpToDate") || newContent.Contains("Complete"))
                                    {
                                        output.AppendLine("   [OK] Completion marker detected in channel.log!");
                                        break;
                                    }
                                }
                            }
                            lastLogLength = fi.Length;
                        }
                    }
                    catch {}
                }

                // Check InstallPending status
                if (sec > 5 && sec % 5 == 0)
                {
                    try
                    {
                        int pending = 0;
                        serviceMgr.InstallPending(channel, out pending);
                        output.AppendLine(string.Format("   [Status @ {0}s] InstallPending('{1}'): {2}", sec, channel, pending));
                    }
                    catch {}
                }
            }

            // 5. Cleanup
            output.AppendLine("Calling StopUpdating...");
            try
            {
                agent.StopUpdating(year, flavor, exePath, 0);
                output.AppendLine("   [OK] StopUpdating called.");
            }
            catch (Exception exStop)
            {
                output.AppendLine("   (StopUpdating notice: " + exStop.Message + ")");
            }

            output.AppendLine("Calling ServiceManager.ApplicationExit()...");
            try
            {
                serviceMgr.ApplicationExit();
                output.AppendLine("   [OK] ApplicationExit called.");
            }
            catch (Exception exExit)
            {
                output.AppendLine("   (ApplicationExit notice: " + exExit.Message + ")");
            }

            output.AppendLine("\n>>> RESULT: Single-channel update test cycle finished! <<<");
        }
        catch (Exception ex)
        {
            output.AppendLine("ERROR: " + ex.ToString());
        }
        finally
        {
            if (rawAgent != null) try { Marshal.ReleaseComObject(rawAgent); } catch {}
            if (rawMgr != null) try { Marshal.ReleaseComObject(rawMgr); } catch {}
        }

        return output.ToString();
    }
}
"@

try {
    Add-Type -TypeDefinition $csharpCode -Language CSharp
} catch {
    Write-Warning "QBUpdateTester notice: $($_.Exception.Message)"
}

$targetExe = "C:\Program Files\Intuit\QuickBooks 2024\qbw.exe"
if (-not (Test-Path $targetExe)) {
    $targetExe = "C:\Program Files\Intuit\QuickBooks Enterprise Solutions 24.0\qbw.exe"
}

$report = ""
if (Test-Path $targetExe) {
    Write-Host "Target QuickBooks: $targetExe" -ForegroundColor Cyan
    # Run test on "Patch" channel for up to 30 seconds
    $report = [QBUpdateTester]::RunUpdateTest($targetExe, 34, "accountant", "Patch", 30)
} else {
    $report = "QuickBooks 2024 executable not found on this machine."
}

$report | Out-File -FilePath $outFile -Encoding UTF8
Write-Host $report
