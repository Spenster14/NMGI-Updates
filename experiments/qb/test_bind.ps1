# Step 6.5 - Safe first call: Test binding to QuickBooks without triggering updates
# Uses pure IUnknown COM interface definitions (since IServiceManager and IAgent do not implement IDispatch)

$scriptDir = $PSScriptRoot
$outFile = Join-Path $scriptDir "bind_report.txt"

$csharpCode = @"
using System;
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

public class QBBindTest
{
    public static string RunTest(string exePath)
    {
        var output = new System.Text.StringBuilder();
        output.AppendLine("=== Testing QB COM Binding for: " + exePath + " ===");

        object finder = null;
        object info = null;
        object rawMgr = null;
        object rawAgent = null;

        try
        {
            // 1. Get Instance Info via IDispatch (QBInstanceFinder implements IDispatch)
            Type finderType = Type.GetTypeFromProgID("QBInstanceFinder.InstalledInstanceFinder.1");
            if (finderType == null) throw new Exception("QBInstanceFinder.InstalledInstanceFinder.1 not found");
            finder = Activator.CreateInstance(finderType);

            output.AppendLine("Calling GetInstallationFromPath...");
            info = finderType.InvokeMember("GetInstallationFromPath", BindingFlags.InvokeMethod, null, finder, new object[] { exePath });
            if (info == null) throw new Exception("GetInstallationFromPath returned null");

            Type infoType = info.GetType();
            uint ver = Convert.ToUInt32(infoType.InvokeMember("majorVersion", BindingFlags.GetProperty, null, info, null));
            string flavor = Convert.ToString(infoType.InvokeMember("flavor", BindingFlags.GetProperty, null, info, null));
            string path = Convert.ToString(infoType.InvokeMember("exePath", BindingFlags.GetProperty, null, info, null));
            object rel = infoType.InvokeMember("releaseNumber", BindingFlags.GetProperty, null, info, null);

            output.AppendLine(string.Format("   [OK] majorVersion: {0}", ver));
            output.AppendLine(string.Format("   [OK] flavor:       {0}", flavor));
            output.AppendLine(string.Format("   [OK] exePath:      {0}", path));
            output.AppendLine(string.Format("   [OK] releaseNum:   {0}", rel));

            // 2. Instantiate and cast ServiceManager via pure IUnknown interface
            Type mgrType = Type.GetTypeFromProgID("QBDServiceMgr2003.ServiceManager2003.1");
            if (mgrType == null) throw new Exception("QBDServiceMgr2003.ServiceManager2003.1 not found");
            rawMgr = Activator.CreateInstance(mgrType);
            output.AppendLine("Instantiated ServiceManager2003 CoClass successfully.");

            IServiceManager serviceMgr = (IServiceManager)rawMgr;
            output.AppendLine(string.Format("Calling IServiceManager.Initialize({0}, \"{1}\", \"{2}\")...", ver, flavor, path));
            serviceMgr.Initialize(ver, flavor, path);
            output.AppendLine("   [SUCCESS] IServiceManager.Initialize completed cleanly!");

            // 3. Test InstallPending query on "Patch" channel
            try
            {
                int isPending = 0;
                serviceMgr.InstallPending("Patch", out isPending);
                output.AppendLine(string.Format("   [OK] InstallPending('Patch'): {0}", isPending));
            }
            catch (Exception exPending)
            {
                output.AppendLine("   (InstallPending query notice: " + exPending.Message + ")");
            }

            // 4. Instantiate and cast Agent2003 via pure IUnknown interface
            Type agentType = Type.GetTypeFromProgID("QBDAgent2003.Agent2003.1");
            if (agentType != null)
            {
                rawAgent = Activator.CreateInstance(agentType);
                IAgent agent = (IAgent)rawAgent;
                output.AppendLine("   [SUCCESS] Agent2003 CoClass instantiated and cast to IAgent cleanly!");
            }

            // 5. Clean unbind and exit
            output.AppendLine("Calling IServiceManager.ApplicationExit()...");
            serviceMgr.ApplicationExit();
            output.AppendLine("   [SUCCESS] IServiceManager.ApplicationExit completed cleanly!");

            output.AppendLine("\n>>> RESULT: Full COM binding, initialization, and unbinding VERIFIED without errors! <<<");
        }
        catch (Exception ex)
        {
            output.AppendLine("ERROR during test: " + ex.ToString());
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
    Write-Warning "QBBindTest notice: $($_.Exception.Message)"
}

$candidates = @(
    "C:\Program Files\Intuit\QuickBooks 2024\qbw.exe",
    "C:\Program Files\Intuit\QuickBooks Enterprise Solutions 24.0\qbw.exe",
    "C:\Program Files\Intuit\QuickBooks 2023\qbw.exe",
    "C:\Program Files\Intuit\QuickBooks 2022\qbw.exe",
    "C:\Program Files (x86)\Intuit\QuickBooks 2021\qbw32.exe"
)

$targetExe = $null
foreach ($c in $candidates) {
    if (Test-Path $c) {
        $targetExe = $c
        break
    }
}

$report = ""
if ($targetExe) {
    Write-Host "Target QuickBooks found: $targetExe" -ForegroundColor Cyan
    $report = [QBBindTest]::RunTest($targetExe)
} else {
    $report = "No QuickBooks executable found on this machine."
}

$report | Out-File -FilePath $outFile -Encoding UTF8
Write-Host $report
