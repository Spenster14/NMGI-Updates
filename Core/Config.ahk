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

    cachedPath := IniRead(iniFile, "Paths", appName, "")

    if (cachedPath == "NotInstalled") {
        return ""
    } else if (cachedPath != "" && SafeFileExist(cachedPath)) {
        return cachedPath
    } else {
        resolved := pathFn()
        if (resolved != "") {
            IniWrite(resolved, iniFile, "Paths", appName)
        } else {
            IniWrite("NotInstalled", iniFile, "Paths", appName)
        }
        return resolved
    }
}
