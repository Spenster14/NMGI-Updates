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
        
    ; 4. User desktop root
    if (A_Desktop != "C:\Users\Public\Desktop" && DirExist(A_Desktop))
        roots.Push(A_Desktop)
        
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

                if (target == "")
                    continue

                target := ExpandEnvVars(target)
                SplitPath(target, &targetFileName, &targetDir)
                SplitPath(lnkPath, , , , &lnkNameNoExt)

                ShortcutCache.Push({
                    LnkPath: lnkPath,
                    LnkName: lnkNameNoExt,
                    Target: target,
                    TargetExe: StrLower(targetFileName),
                    TargetDir: targetDir,
                    WorkingDir: workingDir,
                    Args: args,
                    Description: desc,
                    IsApplicationsFolder: isAppFolder || InStr(lnkPath, "\Applications\")
                })
            }
        }
    }

    ShortcutCacheInitialized := true
    return ShortcutCache
}

FindShortcutPath(exeNames, namePatterns := [], filterFn := "") {
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
                if (item.TargetExe == targetExe) {
                    exeMatch := true
                    break
                }
            }
            if (!exeMatch)
                continue

            ; 2. Name / Path regex patterns check (if any specified)
            patternMatch := true
            for pattern in namePatterns {
                if (!RegExMatch(item.LnkName, pattern) && !RegExMatch(item.LnkPath, pattern) && !RegExMatch(item.Target, pattern)) {
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
            if (SafeFileExist(item.Target))
                return item.Target
        }
    }

    return ""
}
