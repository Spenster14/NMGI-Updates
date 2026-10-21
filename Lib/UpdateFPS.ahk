#Requires AutoHotkey v2.0
; Lib/UpdateFPS.ahk - Financial Planning Suite / Fiduciary Accounting (FAS) updater module.
; Modernized for AHK v2 with SafeFileExist UNC reachability and standardized return strings.

GetFPSPath() {
    ; Candidate network and local paths
    potentialPaths := [
        "F:\FPS\FAS706\FAS\FAS.EXE",
        "F:\FPS\FAS\FAS.EXE",
        "\\sql1\FPS\FAS706\FAS\FAS.EXE",
        "\\sql1\FPS\FAS\FAS.EXE",
        "\\wbsql1\FPS\FAS706\FAS\FAS.EXE",
        "\\wbsql1\FPS\FAS\FAS.EXE",
        "\\chfsapp1\FPS\FAS706\FAS\FAS.EXE",
        "\\chfsapp1\FPS\FAS\FAS.EXE",
        "\\agcfsapp1\FPS\FAS706\FAS\FAS.EXE",
        "\\agcfsapp1\FPS\FAS\FAS.EXE",
        "\\app1\FPS\FAS706\FAS\FAS.EXE",
        "\\app1\FPS\FAS\FAS.EXE",
        "W:\FPS\FAS706\FAS\FAS.EXE",
        "W:\FPS\FAS\FAS.EXE",
        "X:\FPS\FAS706\FAS\FAS.EXE",
        "X:\FPS\FAS\FAS.EXE",
        "P:\FPS\FAS706\FAS\FAS.EXE",
        "P:\FPS\FAS\FAS.EXE",
        "S:\FPS\FAS706\FAS\FAS.EXE",
        "S:\FPS\FAS\FAS.EXE",
        "T:\FPS\FAS706\FAS\FAS.EXE",
        "T:\FPS\FAS\FAS.EXE",
        "C:\FPS\FAS706\FAS\FAS.EXE",
        "C:\FPS\FAS\FAS.EXE",
        "C:\Program Files (x86)\Thomson Reuters\FPS\FAS706\FAS\FAS.EXE",
        "C:\Program Files (x86)\Thomson Reuters\FPS\FAS\FAS.EXE",
        "C:\Program Files\Thomson Reuters\FPS\FAS706\FAS\FAS.EXE",
        "C:\Program Files\Thomson Reuters\FPS\FAS\FAS.EXE"
    ]

    for index, path in potentialPaths {
        if SafeFileExist(path)
            return path
    }
    return ""
}

FPS(PostUpdate := false) {
    ; --- 0. Clean up any stuck instance ---
    if ProcessExist("FAS.EXE") {
        UpdateStatus("Closing existing FPS instances...", 100, 100)
        TerminateProcessGracefully("FAS.EXE", 2, true)
        UpdateStatus()
    }

    ; --- 1. Validate Installation Path ---
    fpsPath := GetFPSPath()
    if (fpsPath == "") {
        return " - Error (Path not found)"
    }

    ; --- 2. Launch Financial Planning Suite ---
    UpdateStatus("Launching Financial Planning Suite...", 100, 100)
    try {
        Run('"' . fpsPath . '" -r')
    } catch as err {
        try {
            Run(fpsPath)
        } catch as err2 {
            UpdateStatus()
            return " - Error (Launch failed: " . err2.Message . ")"
        }
    }

    ; --- 3. Handle Login ("Log User Into System") ---
    UpdateStatus("Waiting for FPS login...", 100, 100)
    if WinWait("Log User Into System", , 15) {
        WinActivate("Log User Into System")
        pwdBox := InputBox("Please enter the user password for Financial Planning Suite:", "FPS Password", "password")
        if (pwdBox.Result != "OK" || pwdBox.Value == "") {
            try WinClose("Log User Into System")
            TerminateProcessGracefully("FAS.EXE", 2, true)
            UpdateStatus()
            return " - Error (Login cancelled)"
        }

        try {
            loginEl := UIA.ElementFromHandle("Log User Into System")
            pwdEl := loginEl.WaitElement({AutomationId: "txtPassword", Type: "Edit"}, 3000)
            if (pwdEl)
                pwdEl.Value := pwdBox.Value

            okEl := loginEl.WaitElement({AutomationId: "btnOK"}, 3000)
            if (okEl)
                okEl.Click()
            else
                Send("{Enter}")
        } catch as err {
            Send("{Enter}")
        }
    }

    ; --- 4. Dismiss "Open a Client" Dialog ---
    if WinWait("Open a Client", , 10) {
        try {
            clientEl := UIA.ElementFromHandle("Open a Client")
            cancelBtn := clientEl.WaitElement({AutomationId: "btnCancel"}, 3000)
            if (cancelBtn)
                cancelBtn.Click()
            else
                Send("{Esc}")
        } catch {
            Send("{Esc}")
        }
    }

    ; --- 5. Wait for Main Window ---
    UpdateStatus("Waiting for FPS main window...", 100, 100)
    mainHwnd := 0
    if WinWait("Fiduciary Accounting", , 20)
        mainHwnd := WinExist("Fiduciary Accounting")
    else if WinWait("Financial Planning Suite", , 5)
        mainHwnd := WinExist("Financial Planning Suite")
    else if WinWait("ahk_exe FAS.EXE", , 5)
        mainHwnd := WinExist("ahk_exe FAS.EXE")

    if (!mainHwnd) {
        UpdateStatus()
        return " - Error (Main window not found)"
    }

    WinActivate("ahk_id " . mainHwnd)
    WinWaitActive("ahk_id " . mainHwnd, , 5)

    ; Clean up any startup popups/bulletins if present
    HandleBulletins()

    ; --- 6. Navigate to "Check for Updates" ---
    UpdateStatus("Checking for updates...", 100, 100)
    menuClicked := false
    try {
        mainEl := UIA.ElementFromHandle(mainHwnd)
        updateMenuItem := mainEl.FindElement({Name: "Check for Updates", Type: "MenuItem", mm: 2})
        if (updateMenuItem) {
            updateMenuItem.Click()
            menuClicked := true
        }
    }

    if (!menuClicked) {
        ; Keyboard fallback: Alt+H (Help) -> U (Check for Updates)
        WinActivate("ahk_id " . mainHwnd)
        Send("!h")
        Sleep(200)
        Send("u")
    }

    ; --- 7. Check "Web Updates" Window ---
    UpdateStatus("Waiting for Web Updates window...", 100, 100)
    if !WinWait("Web Updates", , 20) {
        UpdateStatus()
        return " - Error (Web Updates window not found)"
    }

    WinActivate("Web Updates")
    webVer := ""
    curVer := ""
    webUpdatesEl := ""

    try {
        webUpdatesEl := UIA.ElementFromHandle("Web Updates")
        lblWeb := webUpdatesEl.WaitElement({AutomationId: "lblWebVersion"}, 5000)
        lblCur := webUpdatesEl.WaitElement({AutomationId: "lblVersion"}, 5000)

        if (lblWeb)
            webVer := (lblWeb.Value != "") ? lblWeb.Value : lblWeb.Name
        if (lblCur)
            curVer := (lblCur.Value != "") ? lblCur.Value : lblCur.Name
    } catch {
        ; Fallback to WinGetText
        txt := WinGetText("Web Updates")
        if InStr(txt, "up to date") || InStr(txt, "No new updates") {
            webVer := "current"
            curVer := "current"
        }
    }

    ; CASE A: Versions match -> already up to date
    if (webVer != "" && curVer != "" && webVer == curVer) {
        try {
            if (webUpdatesEl) {
                closeBtn := webUpdatesEl.FindElement({Name: "Close", Type: "Button", mm: 2})
                if (closeBtn)
                    closeBtn.Click()
                else
                    Send("{Esc}")
            } else {
                Send("{Esc}")
            }
        } catch {
            Send("{Esc}")
        }

        try WinClose("ahk_id " . mainHwnd)
        UpdateStatus()
        return " - No updates"
    }

    ; CASE B: Versions differ -> updates available
    if (webVer != "" && curVer != "" && webVer != curVer) {
        ; Look for automated Install/Update button
        installBtn := ""
        try {
            if (webUpdatesEl) {
                installBtn := webUpdatesEl.FindElement({Name: "Install", Type: "Button", mm: 2})
                if (!installBtn)
                    installBtn := webUpdatesEl.FindElement({Name: "Update", Type: "Button", mm: 2})
                if (!installBtn)
                    installBtn := webUpdatesEl.FindElement({Name: "Next", Type: "Button", mm: 2})
                if (!installBtn)
                    installBtn := webUpdatesEl.FindElement({AutomationId: "btnUpdate"})
            }
        }

        if (installBtn) {
            UpdateStatus("Installing FPS updates...", 100, 100)
            try installBtn.Click()
            Sleep(3000)
            UpdateStatus()
            return " - Updates installed"
        }

        UpdateStatus()
        return " - Updates available (Manual)"
    }

    ; CASE C: Fallback check
    txt := WinGetText("Web Updates")
    if InStr(txt, "No new updates") || InStr(txt, "up to date") {
        try WinClose("Web Updates")
        try WinClose("ahk_id " . mainHwnd)
        UpdateStatus()
        return " - No updates"
    }

    UpdateStatus()
    return " - Updates available (Manual)"
}
