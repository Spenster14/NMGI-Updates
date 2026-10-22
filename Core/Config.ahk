#Requires AutoHotkey v2.0
; Core/Config.ahk - Path cache operations for GUIsettings.ini [Paths] section.
; Extracted from NMGIUpdates.ahk (Milestone 2, Step 2.4).

ResolveAppPath(app, forceRescan := false, iniFile := "GUIsettings.ini") {
    appName := HasProp(app, "Name") ? app.Name : String(app)
    pathFn := HasProp(app, "pathFn") ? app.pathFn : (*) => ""

    if (forceRescan) {
        resolved := pathFn()
        if (resolved != "") {
            IniWrite(resolved, iniFile, "Paths", appName)
        } else {
            IniWrite("NotInstalled", iniFile, "Paths", appName)
        }
        return resolved
    }

    ; Priority 1: Check authoritative desktop shortcuts (C:\Users\Public\Desktop\Applications, etc.)
    scPath := FindAppShortcut(appName)
    if (scPath != "") {
        cachedPath := IniRead(iniFile, "Paths", appName, "")
        if (cachedPath != scPath) {
            IniWrite(scPath, iniFile, "Paths", appName)
        }
        return scPath
    }

    ; Priority 2: Check INI cache
    cachedPath := IniRead(iniFile, "Paths", appName, "")

    if (cachedPath == "NotInstalled") {
        return ""
    } else if (cachedPath != "" && SafeFileExist(cachedPath)) {
        return cachedPath
    } else {
        ; Priority 3: Fallback to manual candidate path lists
        resolved := pathFn()
        if (resolved != "") {
            IniWrite(resolved, iniFile, "Paths", appName)
        } else {
            IniWrite("NotInstalled", iniFile, "Paths", appName)
        }
        return resolved
    }
}
