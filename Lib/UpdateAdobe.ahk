#Requires AutoHotkey v2.0
; Lib/UpdateAdobe.ahk - Adobe Acrobat orchestration module.
; Supports 64-bit and 32-bit Adobe Acrobat DC / Pro / 2020.

GetAdobePath() {
    candidates := [
        "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe",
        "C:\Program Files (x86)\Adobe\Acrobat DC\Acrobat\Acrobat.exe",
        "C:\Program Files (x86)\Adobe\Acrobat 2020\Acrobat\Acrobat.exe",
        "C:\Program Files\Adobe\Acrobat\Acrobat.exe",
        "C:\Program Files (x86)\Adobe\Acrobat\Acrobat.exe",
        "C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe",
        "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
    ]
    for path in candidates {
        if FileExist(path)
            return path
    }
    return ""
}

Adobe(*)
{
    ; --- 0. CLEANUP: Close existing instances ---
    if ProcessExist("Acrobat.exe") {
        UpdateStatus("Closing existing Adobe Acrobat instances...", 100, 100)
        TerminateProcessGracefully("Acrobat.exe", 2, true)
        UpdateStatus()
    }
    if ProcessExist("AdobeARM.exe") {
        TerminateProcessGracefully("AdobeARM.exe", 2, true)
    }

    ; --- 1. Validate Installation Path ---
    adobePath := GetAdobePath()
    if (adobePath == "") {
        return " - Error (Path not found)"
    }

    ; --- 2. Launch Adobe Acrobat ---
    UpdateStatus("Launching Adobe Acrobat...", 100, 100)
    workingDir := RegExReplace(adobePath, "\\[^\\]+$")
    try {
        ShellRun(adobePath, "", workingDir)
    } catch {
        try {
            Run('explorer.exe "' . adobePath . '"')
        } catch as err {
            try {
                Run('"' . adobePath . '"', workingDir)
            } catch as err2 {
                return " - Error (Launch failed: " . err2.Message . ")"
            }
        }
    }

    UpdateStatus("Waiting for Adobe Acrobat to open...", 100, 100)
    adobeHwnd := 0
    startTime := A_TickCount
    loop {
        ; 1. Check canonical Acrobat/Reader SDI window class (does not require OpenProcess)
        if (hwnd := WinExist("ahk_class AcrobatSDIWindow")) {
            adobeHwnd := hwnd
            break
        }
        ; 2. Check title (SetTitleMatchMode 2 allows partial title match)
        if (hwnd := WinExist("Adobe Acrobat")) {
            adobeHwnd := hwnd
            break
        }
        if (hwnd := WinExist("Acrobat Reader")) {
            adobeHwnd := hwnd
            break
        }
        ; 3. Fallback to process name
        if (hwnd := WinExist("ahk_exe Acrobat.exe")) {
            adobeHwnd := hwnd
            break
        }
        if (hwnd := WinExist("ahk_exe AcroRd32.exe")) {
            adobeHwnd := hwnd
            break
        }

        if ((A_TickCount - startTime) >= 20000)
            break
        Sleep(250)
    }

    if (!adobeHwnd) {
        return " - Error (Did not open)"
    }

    try WinActivate(adobeHwnd)
    DllCall("user32\SetForegroundWindow", "ptr", adobeHwnd)
    DllCall("user32\BringWindowToTop", "ptr", adobeHwnd)
    WinWaitActive(adobeHwnd,, 5)

    ; --- 3. Instantly Trigger Update Check (Fast Path for Unlicensed/Trial Environments) ---
    UpdateStatus("Checking for Adobe updates...", 100, 100)

    ; Detect whether Acrobat is running Classic UI (Menu Bar) or Modern New Experience UI (Menu Button)
    is2020 := InStr(adobePath, "2020") ? true : false
    isClassicUI := true ; Default to Classic UI (standard in CPA/enterprise environments)

    ; Only treat as Modern UI if "Menu" hamburger button is explicitly found
    try {
        acrobatEl := UIA.ElementFromHandle(adobeHwnd)
        if (acrobatEl.FindElement({Name: "Menu", Type: "Button", mm: 2})) {
            isClassicUI := false
        }
    }

    try WinActivate(adobeHwnd)
    if (isClassicUI) {
        ; Tier 1: Classic Acrobat DC / Pro 64-bit standard: Alt+H -> c -> Enter
        Send("!h")
        Sleep(250)
        if (is2020) {
            Send("u")
        } else {
            Send("c")
            Sleep(100)
            Send("{Enter}")
        }
    } else {
        ; Modern Acrobat New Experience UI (Hamburger Menu: Alt+F -> L -> C)
        Send("!f")
        Sleep(200)
        Send("l")
        Sleep(200)
        Send("c")
    }

    ; --- 4. Wait for AdobeARM / Updater Window ---
    UpdateStatus("Waiting for Adobe Updater...", 100, 100)
    updaterFound := false

    loop 25 {
        if WinExist("Adobe Acrobat Updater") || WinExist("Adobe Acrobat 2020 Updater") || WinExist("ahk_exe AdobeARM.exe") {
            updaterFound := true
            break
        }

        ; Fallback Tier 2 (after 2s): Try Alt+H -> u -> Enter (Acrobat 2020 / Reader accelerator)
        if (A_Index == 4 && !updaterFound && isClassicUI) {
            try WinActivate(adobeHwnd)
            Send("{Esc}")
            Sleep(150)
            Send("!h")
            Sleep(250)
            Send("u")
            Sleep(100)
            Send("{Enter}")
        }

        ; Fallback Tier 3 (after 4s): Try Alt+H -> {Up} (wraps to bottom item in Help menu) -> Enter
        if (A_Index == 8 && !updaterFound && isClassicUI) {
            try WinActivate(adobeHwnd)
            Send("{Esc}")
            Sleep(150)
            Send("!h")
            Sleep(250)
            Send("{Up}")
            Sleep(100)
            Send("{Enter}")
        }

        ; Fallback Tier 4 (after 6s): UIA search across desktop popup menus
        if (A_Index == 12 && !updaterFound) {
            try {
                updateItem := UIA.GetRootElement().FindElement({Name: "(?i)check for updates", mm: "regex"})
                if (updateItem)
                    updateItem.Click()
            } catch {
                try {
                    acrobatEl := UIA.ElementFromHandle(adobeHwnd)
                    helpBtn := acrobatEl.FindElement({Name: "Help", mm: 2})
                    if (helpBtn) {
                        helpBtn.Click()
                        Sleep(250)
                        updateItem := UIA.GetRootElement().FindElement({Name: "(?i)check for updates", mm: "regex"})
                        if (updateItem)
                            updateItem.Click()
                    }
                }
            }
        }

        Sleep(500)
    }

    if (!updaterFound) {
        TerminateProcessGracefully("Acrobat.exe", 2, true)
        return " - Error (Updater window not found)"
    }

    ; --- 5. Monitor Update Status ---
    UpdateStatus("Monitoring Adobe update status...", 100, 100)
    startTime := A_TickCount
    updateResult := ""
    windowSawResult := false

    loop {
        ; Timeout after 3 minutes
        if (A_TickCount - startTime > 180000) {
            updateResult := " - Error (Updater timeout)"
            break
        }

        ; Dynamically locate the current active updater window
        armHwnd := WinExist("Adobe Acrobat Updater") ? WinExist("Adobe Acrobat Updater") : (WinExist("Adobe Acrobat 2020 Updater") ? WinExist("Adobe Acrobat 2020 Updater") : WinExist("ahk_exe AdobeARM.exe"))

        if (armHwnd) {
            try {
                armEl := UIA.ElementFromHandle(armHwnd)

                ; Check for "No updates available"
                if armEl.FindElement({Name: "No updates available", mm: 2}) {
                    updateResult := " - No updates"
                    windowSawResult := true
                    try armEl.FindElement({Name: "Close", Type: "Button", mm: 2}).Highlight().Click()
                    break
                }

                ; Check for success states
                if armEl.FindElement({Name: "Update successful", mm: 2}) || armEl.FindElement({Name: "successful", mm: 2}) {
                    updateResult := " - Updates installed"
                    windowSawResult := true
                    try armEl.FindElement({Name: "Close", Type: "Button", mm: 2}).Highlight().Click()
                    break
                }

                ; Check for downloadable / installable updates
                installBtn := armEl.FindElement({Name: "Download and Install", Type: "Button", mm: 2})
                if (!installBtn)
                    installBtn := armEl.FindElement({Name: "Install Now", Type: "Button", mm: 2})
                if (installBtn) {
                    installBtn.Click()
                    UpdateStatus("Installing Adobe updates...", 100, 100)
                    Sleep(3000)
                    continue
                }

                ; Check for manual or failure states
                if armEl.FindElement({Name: "Update failed", mm: 2}) || armEl.FindElement({Name: "An error occurred", mm: 2}) {
                    updateResult := " - Error (Update failed)"
                    windowSawResult := true
                    try armEl.FindElement({Name: "Close", Type: "Button", mm: 2}).Highlight().Click()
                    break
                }
            }
        } else {
            ; If window has vanished after we saw a result or after a grace period
            if (windowSawResult) {
                break
            } else if (A_TickCount - startTime > 15000) {
                updateResult := " - Error (Updater window closed unexpectedly)"
                break
            }
        }

        Sleep(500)
    }

    ; --- 6. Post-execution Teardown ---
    TerminateProcessGracefully("AdobeARM.exe", 2, true)
    TerminateProcessGracefully("Acrobat.exe", 2, true)
    UpdateStatus()

    return (updateResult != "") ? updateResult : " - Error (Unknown update state)"
}
