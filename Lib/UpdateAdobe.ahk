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
    try {
        Run(adobePath)
    } catch as err {
        return " - Error (Launch failed: " . err.Message . ")"
    }

    UpdateStatus("Waiting for Adobe Acrobat to open...", 100, 100)
    if !WinWait("ahk_exe Acrobat.exe",, 15) {
        return " - Error (Did not open)"
    }

    WinActivate("ahk_exe Acrobat.exe")
    WinWaitActive("ahk_exe Acrobat.exe",, 3)

    ; --- 3. Instantly Trigger Update Check (Fast Path for Unlicensed/Trial Environments) ---
    UpdateStatus("Checking for Adobe updates...", 100, 100)

    ; Method 1: Instant Alt+F -> L -> C keystroke dispatch (<400ms)
    WinActivate("ahk_exe Acrobat.exe")
    Send("!f")
    Sleep(150)
    Send("l")
    Sleep(150)
    Send("c")

    ; --- 4. Wait for AdobeARM / Updater Window ---
    UpdateStatus("Waiting for Adobe Updater...", 100, 100)
    updaterFound := false

    loop 15 {
        if WinExist("Adobe Acrobat Updater") || WinExist("Adobe Acrobat 2020 Updater") || WinExist("ahk_exe AdobeARM.exe") {
            updaterFound := true
            break
        }

        ; Fallback: If not open after 2 seconds, try UIA Menu -> Help -> Check for updates
        if (A_Index == 4 && !updaterFound) {
            try {
                acrobatEl := UIA.ElementFromHandle("ahk_exe Acrobat.exe")
                menuBtn := acrobatEl.FindElement({Name: "Menu", mm: 2})
                if (menuBtn) {
                    menuBtn.Click()
                    Sleep(200)
                    helpItem := UIA.WaitElement({Name: "Help", mm: 2}, 1500)
                    if (helpItem) {
                        helpItem.Click()
                        Sleep(200)
                        updateItem := UIA.WaitElement({Name: "Check for updates", mm: 2}, 1500)
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
