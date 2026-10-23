# Step 6.5 - Safe first call: Test binding to QuickBooks without triggering updates
# Performs: GetInstallationFromPath -> cServiceManager.Initialize -> ApplicationExit

$scriptDir = $PSScriptRoot
$outFile = Join-Path $scriptDir "bind_report.txt"

$csharpCode = @"
using System;
using System.Reflection;
using System.Runtime.InteropServices;

public class QBBindTest
{
    public static string RunTest(string exePath)
    {
        var output = new System.Text.StringBuilder();
        output.AppendLine("=== Testing QB COM Binding for: " + exePath + " ===");

        object finder = null;
        object info = null;
        object mgr = null;
        object agent = null;

        try
        {
            // 1. Get Instance Info
            Type finderType = Type.GetTypeFromProgID("QBInstanceFinder.InstalledInstanceFinder.1");
            if (finderType == null) throw new Exception("QBInstanceFinder.InstalledInstanceFinder.1 not found");
            finder = Activator.CreateInstance(finderType);

            output.AppendLine("Calling GetInstallationFromPath...");
            info = finderType.InvokeMember("GetInstallationFromPath", BindingFlags.InvokeMethod, null, finder, new object[] { exePath });
            if (info == null) throw new Exception("GetInstallationFromPath returned null");

            Type infoType = info.GetType();
            object ver = infoType.InvokeMember("majorVersion", BindingFlags.GetProperty, null, info, null);
            object flavor = infoType.InvokeMember("flavor", BindingFlags.GetProperty, null, info, null);
            object path = infoType.InvokeMember("exePath", BindingFlags.GetProperty, null, info, null);
            object rel = infoType.InvokeMember("releaseNumber", BindingFlags.GetProperty, null, info, null);

            output.AppendLine(string.Format("   [OK] majorVersion: {0}", ver));
            output.AppendLine(string.Format("   [OK] flavor:       {0}", flavor));
            output.AppendLine(string.Format("   [OK] exePath:      {0}", path));
            output.AppendLine(string.Format("   [OK] releaseNum:   {0}", rel));

            // 2. Initialize ServiceManager
            Type mgrType = Type.GetTypeFromProgID("QBDServiceMgr2003.ServiceManager2003.1");
            if (mgrType == null) throw new Exception("QBDServiceMgr2003.ServiceManager2003.1 not found");
            mgr = Activator.CreateInstance(mgrType);
            output.AppendLine("Instantiated ServiceManager2003 successfully.");

            output.AppendLine(string.Format("Calling cServiceManager.Initialize({0}, \"{1}\", \"{2}\")...", ver, flavor, path));
            mgrType.InvokeMember("Initialize", BindingFlags.InvokeMethod, null, mgr, new object[] { ver, flavor, path });
            output.AppendLine("   [SUCCESS] ServiceManager.Initialize completed cleanly!");

            // Query ComponentDir or Status
            try
            {
                object compDir = mgrType.InvokeMember("ComponentDir", BindingFlags.InvokeMethod, null, mgr, new object[] { "" });
                output.AppendLine(string.Format("   [OK] ComponentDir: {0}", compDir));
            }
            catch (Exception exDir)
            {
                output.AppendLine("   (ComponentDir query: " + exDir.Message + ")");
            }

            // 3. Instantiate Agent2003
            Type agentType = Type.GetTypeFromProgID("QBDAgent2003.Agent2003.1");
            if (agentType != null)
            {
                agent = Activator.CreateInstance(agentType);
                output.AppendLine("   [SUCCESS] Agent2003 instantiated cleanly!");
            }

            // 4. Clean exit
            output.AppendLine("Calling cServiceManager.ApplicationExit()...");
            mgrType.InvokeMember("ApplicationExit", BindingFlags.InvokeMethod, null, mgr, null);
            output.AppendLine("   [SUCCESS] ServiceManager.ApplicationExit completed cleanly!");

            output.AppendLine("\n>>> RESULT: Full COM binding and unbinding verified without errors! <<<");
        }
        catch (Exception ex)
        {
            output.AppendLine("ERROR during test: " + ex.ToString());
        }
        finally
        {
            if (agent != null) try { Marshal.ReleaseComObject(agent); } catch {}
            if (mgr != null) try { Marshal.ReleaseComObject(mgr); } catch {}
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
