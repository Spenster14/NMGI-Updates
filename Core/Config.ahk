#Requires AutoHotkey v2.0
; Core/Config.ahk - Path cache operations for GUIsettings.ini [Paths] section.
; Extracted from NMGIUpdates.ahk (Milestone 2, Step 2.4).

ResolveAppPath(app, forceRescan := false, iniFile := "GUIsettings.ini") {
    appName := HasProp(app, "Name") ? app.Name : String(app)
    pathFn := HasProp(app, "pathFn") ? app.pathFn : (*) => ""

    SetAppSource(srcDesc) {
        if (IsObject(app) && HasProp(app, "Name"))
            app.Source := srcDesc
    }

    if (forceRescan) {
        scInfo := FindAppShortcutInfo(appName)
        if (scInfo) {
            srcDesc := "Shortcut: " . scInfo.LnkPath
            IniWrite(scInfo.Target, iniFile, "Paths", appName)
            IniWrite(srcDesc, iniFile, "PathSources", appName)
            SetAppSource(srcDesc)
            return scInfo.Target
        }

        resolved := pathFn()
        if (resolved != "") {
            IniWrite(resolved, iniFile, "Paths", appName)
            IniWrite("FallbackScan", iniFile, "PathSources", appName)
            SetAppSource("FallbackScan")
        } else {
            IniWrite("NotInstalled", iniFile, "Paths", appName)
            IniWrite("NotInstalled", iniFile, "PathSources", appName)
            SetAppSource("NotInstalled")
        }
        return resolved
    }

    ; Priority 1: Check authoritative desktop shortcuts (C:\Users\Public\Desktop\Applications, etc.)
    scInfo := FindAppShortcutInfo(appName)
    if (scInfo) {
        cachedPath := IniRead(iniFile, "Paths", appName, "")
        if (cachedPath != scInfo.Target) {
            IniWrite(scInfo.Target, iniFile, "Paths", appName)
        }
        srcDesc := "Shortcut: " . scInfo.LnkPath
        IniWrite(srcDesc, iniFile, "PathSources", appName)
        SetAppSource(srcDesc)
        return scInfo.Target
    }

    ; Priority 2: Check INI cache
    cachedPath := IniRead(iniFile, "Paths", appName, "")
    cachedSource := IniRead(iniFile, "PathSources", appName, "")

    if (cachedPath == "NotInstalled") {
        if (cachedSource == "")
            IniWrite("NotInstalled", iniFile, "PathSources", appName)
        SetAppSource("NotInstalled")
        return ""
    } else if (cachedPath != "" && SafeFileExist(cachedPath)) {
        if (cachedSource == "") {
            cachedSource := InStr(cachedPath, "\\") ? "UNC Path" : "FallbackScan"
            IniWrite(cachedSource, iniFile, "PathSources", appName)
        }
        SetAppSource(cachedSource)
        return cachedPath
    } else {
        ; Priority 3: Fallback to manual candidate path lists
        resolved := pathFn()
        if (resolved != "") {
            IniWrite(resolved, iniFile, "Paths", appName)
            IniWrite("FallbackScan", iniFile, "PathSources", appName)
            SetAppSource("FallbackScan")
        } else {
            IniWrite("NotInstalled", iniFile, "Paths", appName)
            IniWrite("NotInstalled", iniFile, "PathSources", appName)
            SetAppSource("NotInstalled")
        }
        return resolved
    }
}
