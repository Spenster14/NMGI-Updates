#Requires AutoHotkey v2.0
; Core/ShortcutScanner.ahk - Recursive desktop shortcut indexing & application path discovery.
; Prioritizes C:\Users\Public\Desktop\Applications (and recursive subfolders) over candidate path lists.
; Part of Milestone 5 (Step 5.1).

global ShortcutCache := []
global ShortcutCacheInitialized := false

ClearShortcutCache() {
    global ShortcutCache, ShortcutCacheInitialized
    ShortcutCache := []
    ShortcutCacheInitialized := false
}

GetShortcutSearchRoots() {
    roots := []
    
    ; 1. Primary NMGI standard deployed applications folder
    if DirExist("C:\Users\Public\Desktop\Applications")
        roots.Push("C:\Users\Public\Desktop\Applications")
        
    ; 2. User-specific desktop applications folder
    userAppDir := A_Desktop . "\Applications"
    if (userAppDir != "C:\Users\Public\Desktop\Applications" && DirExist(userAppDir))
        roots.Push(userAppDir)
        
    ; 3. Public desktop root
    if DirExist("C:\Users\Public\Desktop")
        roots.Push("C:\Users\Public\Desktop")
    if (A_DesktopCommon != "" && A_DesktopCommon != "C:\Users\Public\Desktop" && DirExist(A_DesktopCommon))
        roots.Push(A_DesktopCommon)
        
    ; 4. User desktop root
    if (A_Desktop != "C:\Users\Public\Desktop" && DirExist(A_Desktop))
        roots.Push(A_Desktop)
    localUserDesktop := "C:\Users\" . A_UserName . "\Desktop"
    if (localUserDesktop != A_Desktop && localUserDesktop != "C:\Users\Public\Desktop" && DirExist(localUserDesktop))
        roots.Push(localUserDesktop)
        
    return roots
}

ExpandEnvVars(str) {
    if (!InStr(str, "%"))
        return str
    bufSize := DllCall("ExpandEnvironmentStrings", "Str", str, "Ptr", 0, "UInt", 0, "UInt")
    if (bufSize <= 0)
        return str
    buf := Buffer(bufSize * 2, 0)
    DllCall("ExpandEnvironmentStrings", "Str", str, "Ptr", buf.Ptr, "UInt", bufSize)
    return StrGet(buf.Ptr)
}

ResolveAdvertisedShortcut(lnkPath) {
    ; Tier 1: WindowsInstaller.Installer COM Automation
    try {
        installer := ComObject("WindowsInstaller.Installer")
        targetRec := installer.ShortcutTarget(lnkPath)
        if (targetRec) {
            prod := targetRec.StringData(1)
            comp := targetRec.StringData(3)
            if (prod != "" && comp != "") {
                compPath := installer.ComponentPath(prod, comp)
                if (compPath != "" && !InStr(compPath, "\Installer\"))
                    return compPath
            }
        }
    } catch {
    }

    ; Tier 2: Win32 MSI API (msi.dll)
    try {
        productCode := Buffer(256, 0)
        featureId := Buffer(256, 0)
        componentCode := Buffer(256, 0)
        res := DllCall("msi\MsiGetShortcutTargetW",
            "WStr", lnkPath,
            "Ptr", productCode.Ptr,
            "Ptr", featureId.Ptr,
            "Ptr", componentCode.Ptr,
            "UInt")
        if (res == 0) {
            cchBuf := 1024
            buf := Buffer(cchBuf * 2, 0)
            installState := DllCall("msi\MsiGetComponentPathW",
                "Ptr", productCode.Ptr,
                "Ptr", componentCode.Ptr,
                "Ptr", buf.Ptr,
                "UInt*", &cchBuf,
                "Int")
            ; INSTALLSTATE_LOCAL = 3, INSTALLSTATE_SOURCE = 4
            if (installState == 3 || installState == 4) {
                targetPath := StrGet(buf.Ptr, "UTF-16")
                if (targetPath != "" && !InStr(targetPath, "\Installer\"))
                    return targetPath
            }
        }
    } catch {
    }

    return ""
}

IndexShortcuts(forceRefresh := false) {
    global ShortcutCache, ShortcutCacheInitialized
    if (ShortcutCacheInitialized && !forceRefresh)
        return ShortcutCache

    ShortcutCache := []
    seenLnkPaths := Map()

    for rootDir in GetShortcutSearchRoots() {
        isAppFolder := InStr(rootDir, "\Applications") ? true : false
        try {
            Loop Files, rootDir . "\*.lnk", "R" {
                lnkPath := A_LoopFileFullPath
                lnkLower := StrLower(lnkPath)
                if seenLnkPaths.Has(lnkLower)
                    continue
                seenLnkPaths[lnkLower] := true

                target := "", workingDir := "", args := "", desc := ""
                try {
                    FileGetShortcut(lnkPath, &target, &workingDir, &args, &desc)
                } catch {
                    continue
                }

                ; Fallback for Windows Installer (MSI) Advertised Shortcuts
                ; Advertised shortcuts either return an empty target or an internal MSI stub (e.g. C:\Windows\Installer\{GUID}\...exe)
                isAdv := (target == "" || InStr(target, "\Windows\Installer\") || InStr(target, "\Installer\"))
                if (isAdv) {
                    advTarget := ResolveAdvertisedShortcut(lnkPath)
                    if (advTarget != "") {
                        target := advTarget
                        isAdv := false
                    }
                }

                ; If still pointing to an internal installer stub, clear target
                if (InStr(target, "\Windows\Installer\") || InStr(target, "\Installer\"))
                    target := ""

                target := Trim(ExpandEnvVars(target), '" ')
                SplitPath(target, &targetFileName, &targetDir)
                SplitPath(lnkPath, , , , &lnkNameNoExt)

                if (workingDir == "" && targetDir != "")
                    workingDir := targetDir

                ; Keep entries that have either a valid target OR are an Advertised Shortcut matching a known application
                if (target == "" && !isAdv)
                    continue

                ShortcutCache.Push({
                    LnkPath: lnkPath,
                    LnkName: lnkNameNoExt,
                    Target: target,
                    TargetExe: targetFileName != "" ? StrLower(targetFileName) : "",
                    TargetDir: targetDir,
                    WorkingDir: workingDir,
                    Args: args,
                    Description: desc,
                    IsAdvertised: isAdv,
                    IsApplicationsFolder: isAppFolder || InStr(lnkPath, "\Applications\")
                })
            }
        }
    }

    ShortcutCacheInitialized := true
    return ShortcutCache
}

FindShortcutInfo(exeNames, namePatterns := [], filterFn := "") {
    scList := IndexShortcuts()
    if (scList.Length == 0)
        return ""

    ; Normalize exeNames to lowercase array
    if !IsObject(exeNames)
        exeNames := [exeNames]
    cleanExes := []
    for exe in exeNames {
        if (exe != "")
            cleanExes.Push(StrLower(exe))
    }

    ; Normalize namePatterns to array
    if !IsObject(namePatterns)
        namePatterns := namePatterns != "" ? [namePatterns] : []

    ; Two-pass search:
    ; Pass 1: Shortcuts within an Applications folder (strict priority)
    ; Pass 2: Root desktop shortcuts (fallback)
    for pass in [1, 2] {
        for item in scList {
            if (pass == 1 && !item.IsApplicationsFolder)
                continue
            if (pass == 2 && item.IsApplicationsFolder)
                continue

            ; 1. Executable name check
            exeMatch := false
            for targetExe in cleanExes {
                if (item.TargetExe != "" && item.TargetExe == targetExe) {
                    exeMatch := true
                    break
                }
            }
            ; Allow advertised shortcuts with unresolved target to match on name patterns
            if (!exeMatch && (!HasProp(item, "IsAdvertised") || !item.IsAdvertised || namePatterns.Length == 0))
                continue

            ; 2. Name / Path regex patterns check (if any specified)
            patternMatch := true
            for pattern in namePatterns {
                if (!RegExMatch(item.LnkName, pattern) && !RegExMatch(item.LnkPath, pattern) && (item.Target == "" || !RegExMatch(item.Target, pattern))) {
                    patternMatch := false
                    break
                }
            }
            if (!patternMatch)
                continue

            ; 3. Optional custom filter closure
            if (filterFn != "" && !filterFn(item))
                continue

            ; 4. Validate physical reachability and existence
            if (item.Target != "" && SafeFileExist(item.Target))
                return { Target: item.Target, LnkPath: item.LnkPath, LnkName: item.LnkName, IsApplicationsFolder: item.IsApplicationsFolder }
            else if (HasProp(item, "IsAdvertised") && item.IsAdvertised && item.Target == "")
                return { Target: "", LnkPath: item.LnkPath, LnkName: item.LnkName, IsApplicationsFolder: item.IsApplicationsFolder }
        }
    }

    return ""
}

FindShortcutPath(exeNames, namePatterns := [], filterFn := "") {
    info := FindShortcutInfo(exeNames, namePatterns, filterFn)
    return info ? info.Target : ""
}

FindAppShortcutInfo(appName) {
    if (appName == "FixedAssetsCS")
        return FindShortcutInfo("dsw.exe", ["(?i)Fixed\s*Assets|(?i)\bDSW\b"])
    if (appName == "FileCabinet")
        return FindShortcutInfo("fcab.exe", ["(?i)FileCabinet|(?i)File\s*Cabinet"])
    if (appName == "AccountingCS")
        return FindShortcutInfo(["AccountingCS.exe", "acs.exe"], ["(?i)Accounting\s*CS|(?i)\bACS\b"])
    if (appName == "PracticeCS")
        return FindShortcutInfo(["CreativeSolutions.Practice.exe", "PracticeCS.exe", "practice.exe"], ["(?i)Practice\s*CS"])
    if (appName == "FPS")
        return FindShortcutInfo("FAS.EXE", ["(?i)Financial\s*Planning|(?i)\bFPS\b|(?i)\bFAS\b"])
    if (appName == "PPC")
        return FindShortcutInfo("PPCWebMultiSelect.exe", ["(?i)PPC|(?i)Practice\s*Aids"])

    ; UltraTax
    if RegExMatch(appName, "^Ultratax\s*(\d+)", &m) {
        yr := m[1]
        return FindShortcutInfo("utw" . yr . ".exe", ["(?i)UltraTax.*20" . yr . "|(?i)UT.*" . yr . "|(?i)UltraTax.*" . yr])
    }

    ; QuickBooks
    if RegExMatch(appName, "^Quickbooks\s*(Enterprise|Premier)\s*(\d+)", &m) {
        ed := m[1]
        yr := m[2]
        isEnt := (ed == "Enterprise")
        return FindShortcutInfo(
            ["qbw32.exe", "QBWEnterpriseAccountant.exe", "QBWEnterprise.exe", "QBWPremierAccountant.exe", "QBWPremier.exe", "QBWPro.exe", "QBW32Enterprise.exe", "QBW32EnterpriseAccountant.exe"],
            ,
            (item) => (
                (isEnt ? (InStr(item.Target, "Enterprise") || InStr(item.LnkName, "Enterprise")) : (!InStr(item.Target, "Enterprise") && !InStr(item.LnkName, "Enterprise")))
                && (InStr(item.Target, "20" . yr) || InStr(item.Target, " " . yr . ".") || InStr(item.LnkName, "20" . yr) || InStr(item.LnkName, yr))
            )
        )
    }

    ; Lacerte
    if RegExMatch(appName, "^Lacerte\s*(\d+)", &m) {
        yr := m[1]
        return FindShortcutInfo(["w" . yr . "tax-launcher.exe", "w" . yr . "tax.exe"], ["(?i)Lacerte.*20" . yr . "|(?i)20" . yr . ".*Lacerte|(?i)Lacerte.*" . yr])
    }

    ; Adobe Acrobat
    if (appName == "Adobe Acrobat")
        return FindShortcutInfo(["Acrobat.exe", "AcroRd32.exe"], ["(?i)Adobe\s*Acrobat|(?i)\bAcrobat\b|(?i)Adobe\s*Reader"])

    ; Browsers
    if (appName == "Chrome")
        return FindShortcutInfo("chrome.exe", ["(?i)Google\s*Chrome|(?i)\bChrome\b"])
    if (appName == "Edge")
        return FindShortcutInfo("msedge.exe", ["(?i)Microsoft\s*Edge|(?i)\bEdge\b"])
    if (appName == "Firefox")
        return FindShortcutInfo("firefox.exe", ["(?i)Mozilla\s*Firefox|(?i)\bFirefox\b"])

    return ""
}

FindAppShortcut(appName) {
    info := FindAppShortcutInfo(appName)
    return info ? info.Target : ""
}
