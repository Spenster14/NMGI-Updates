#Requires AutoHotkey v2.0
; Core/Config.ahk - Path cache operations for GUIsettings.ini [Paths] section.
; Extracted from NMGIUpdates.ahk (Milestone 2, Step 2.4).

ResolveAppPath(app, forceRescan := false, iniFile := "GUIsettings.ini") {
    if (forceRescan) {
        resolved := app.pathFn()
        if (resolved != "") {
            IniWrite(resolved, iniFile, "Paths", app.Name)
        } else {
            IniWrite("NotInstalled", iniFile, "Paths", app.Name)
        }
        return resolved
    }

    cachedPath := IniRead(iniFile, "Paths", app.Name, "")

    if (cachedPath == "NotInstalled") {
        return ""
    } else if (cachedPath != "" && FileExist(cachedPath)) {
        return cachedPath
    } else {
        resolved := app.pathFn()
        if (resolved != "") {
            IniWrite(resolved, iniFile, "Paths", app.Name)
        } else {
            IniWrite("NotInstalled", iniFile, "Paths", app.Name)
        }
        return resolved
    }
}
