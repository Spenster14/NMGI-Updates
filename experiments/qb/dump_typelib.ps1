# Step 6.3 - Dump COM Type Library interfaces, methods, and parameter signatures
# Directly loads TypeLib from qbupdate.exe, QBUServiceMgr.dll, and QBInstanceFinder.dll

$scriptDir = $PSScriptRoot
$outFile = Join-Path $scriptDir "typelib_dump.txt"

if (Test-Path $outFile) { Remove-Item $outFile -Force -ErrorAction SilentlyContinue }

$csharpCode = @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

public class TypeLibReader
{
    public enum REGKIND { REGKIND_DEFAULT = 0, REGKIND_REGISTER = 1, REGKIND_NONE = 2 }

    [DllImport("oleaut32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
    public static extern void LoadTypeLibEx(string szFile, REGKIND regkind, [MarshalAs(UnmanagedType.Interface)] out ITypeLib pptlib);

    public static List<string> DumpFile(string path)
    {
        var output = new List<string>();
        output.Add("=== TypeLib Dump for: " + path + " ===");

        ITypeLib typeLib = null;
        try
        {
            LoadTypeLibEx(path, REGKIND.REGKIND_NONE, out typeLib);
        }
        catch (Exception ex)
        {
            output.Add("ERROR loading TypeLib: " + ex.Message);
            return output;
        }

        int count = typeLib.GetTypeInfoCount();
        output.Add("TypeInfo Count: " + count);

        for (int i = 0; i < count; i++)
        {
            ITypeInfo info;
            typeLib.GetTypeInfo(i, out info);
            string name, doc, helpFile;
            int helpCtx;
            typeLib.GetDocumentation(i, out name, out doc, out helpCtx, out helpFile);

            IntPtr pAttr;
            info.GetTypeAttr(out pAttr);
            System.Runtime.InteropServices.ComTypes.TYPEATTR attr = (System.Runtime.InteropServices.ComTypes.TYPEATTR)Marshal.PtrToStructure(pAttr, typeof(System.Runtime.InteropServices.ComTypes.TYPEATTR));

            output.Add("\n[" + attr.typekind + "] " + name + " (GUID: " + attr.guid + ")");
            if (!string.IsNullOrEmpty(doc)) output.Add("   Doc: " + doc);

            if (attr.typekind == System.Runtime.InteropServices.ComTypes.TYPEKIND.TKIND_INTERFACE ||
                attr.typekind == System.Runtime.InteropServices.ComTypes.TYPEKIND.TKIND_DISPATCH ||
                attr.typekind == System.Runtime.InteropServices.ComTypes.TYPEKIND.TKIND_COCLASS)
            {
                for (int f = 0; f < attr.cFuncs; f++)
                {
                    IntPtr pFunc;
                    try
                    {
                        info.GetFuncDesc(f, out pFunc);
                        System.Runtime.InteropServices.ComTypes.FUNCDESC func = (System.Runtime.InteropServices.ComTypes.FUNCDESC)Marshal.PtrToStructure(pFunc, typeof(System.Runtime.InteropServices.ComTypes.FUNCDESC));

                        string[] names = new string[func.cParams + 1];
                        int nameCount;
                        info.GetNames(func.memid, names, names.Length, out nameCount);

                        string funcName = names[0];
                        var paramNames = new List<string>();
                        for (int p = 1; p < nameCount; p++)
                        {
                            paramNames.Add(names[p]);
                        }

                        output.Add(string.Format("   Method: {0} ({1}) [invkind={2}, params={3}]",
                            funcName,
                            string.Join(", ", paramNames.ToArray()),
                            func.invkind,
                            func.cParams));

                        info.ReleaseFuncDesc(pFunc);
                    }
                    catch (Exception fex)
                    {
                        output.Add("   Method error: " + fex.Message);
                    }
                }
            }

            info.ReleaseTypeAttr(pAttr);
        }

        output.Add("");
        return output;
    }
}
"@

try {
    Add-Type -TypeDefinition $csharpCode -Language CSharp
} catch {
    Write-Warning "TypeLibReader already loaded or compilation notice: $($_.Exception.Message)"
}

$candidatePaths = @(
    "C:\Program Files\Common Files\Intuit\QuickBooks\QBUpdate\qbupdate.exe",
    "C:\Program Files\Common Files\Intuit\QuickBooks\QBUpdate\QBUServiceMgr.dll",
    "C:\Program Files\Common Files\Intuit\QuickBooks\QBInstanceFinder.dll",
    "C:\Program Files (x86)\Common Files\Intuit\QuickBooks\QBUpdate\qbupdate.exe",
    "C:\Program Files (x86)\Common Files\Intuit\QuickBooks\QBUpdate\QBUServiceMgr.dll",
    "C:\Program Files (x86)\Common Files\Intuit\QuickBooks\QBInstanceFinder.dll"
)

$results = New-Object System.Collections.Generic.List[string]
$results.Add("QuickBooks COM TypeLib Inspection - $(Get-Date) - Host: $env:COMPUTERNAME")
$results.Add("")

$foundAny = $false
foreach ($p in $candidatePaths) {
    if (Test-Path $p) {
        $foundAny = $true
        Write-Host "Reading TypeLib from: $p" -ForegroundColor Cyan
        $dump = [TypeLibReader]::DumpFile($p)
        foreach ($line in $dump) {
            $results.Add($line)
        }
    }
}

if (-not $foundAny) {
    $results.Add("None of the standard target QuickBooks binaries were found on this machine.")
}

$results | Out-File -FilePath $outFile -Encoding UTF8
Write-Host "Output written to: $outFile ($($results.Count) lines)" -ForegroundColor Green

# Print summary to console
$results | Select-Object -First 100 | ForEach-Object { Write-Host $_ }
if ($results.Count -gt 100) {
    Write-Host "... (Output truncated in console, view $outFile for all $($results.Count) lines) ..." -ForegroundColor Yellow
}
