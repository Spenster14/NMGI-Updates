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

    ; Detect whether Acrobat is running the New Experience UI, Classic DC UI, or Acrobat 2020
    is2020 := InStr(adobePath, "2020") ? true : false
    isNewUI := true

    if (is2020) {
        isNewUI := false
    } else {
        try {
            if (RegRead("HKEY_CURRENT_USER\Software\Adobe\Adobe Acrobat\DC\AVGeneral", "bEnableAV2") == 0)
                isNewUI := false
        }
        try {
            if (RegRead("HKEY_CURRENT_USER\Software\Adobe\Acrobat Reader\DC\AVGeneral", "bEnableAV2") == 0)
                isNewUI := false
        }
    }

    WinActivate("ahk_exe Acrobat.exe")
    if (isNewUI) {
        ; Modern Acrobat New Experience UI (Hamburger Menu: Alt+F -> L -> C)
        Send("!f")
        Sleep(150)
        Send("l")
        Sleep(150)
        Send("c")
    } else if (is2020) {
        ; Acrobat 2020 (Top-level Menu Bar: Alt+H -> U)
        Send("!h")
        Sleep(150)
        Send("u")
    } else {
        ; Classic Acrobat DC UI (Top-level Menu Bar: Alt+H -> C)
        Send("!h")
        Sleep(150)
        Send("c")
    }

    ; --- 4. Wait for AdobeARM / Updater Window ---
    UpdateStatus("Waiting for Adobe Updater...", 100, 100)
    updaterFound := false

    loop 15 {
        if WinExist("Adobe Acrobat Updater") || WinExist("Adobe Acrobat 2020 Updater") || WinExist("ahk_exe AdobeARM.exe") {
            updaterFound := true
            break
        }

        ; Fallback: If not open after 2 seconds, try UIA / Alternative Key sequence
        if (A_Index == 4 && !updaterFound) {
            try {
                acrobatEl := UIA.ElementFromHandle("ahk_exe Acrobat.exe")
                menuBtn := acrobatEl.FindElement({Name: "Menu", mm: 2})
                if (menuBtn) {
                    ; Confirmed New UI via UIA
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
                } else {
                    ; Confirmed Classic UI via UIA
                    helpItem := acrobatEl.FindElement({Name: "Help", Type: "MenuItem", Order: "LastToFirstOrder"})
                    if (helpItem) {
                        helpItem.Click()
                        Sleep(200)
                        updateItem := acrobatEl.WaitElement({Name: "Check for Updates...", Type: "MenuItem", Order: "LastToFirstOrder"}, 1500)
                        if (!updateItem)
                            updateItem := UIA.WaitElement({Name: "Check for updates", mm: 2}, 1500)
                        if (updateItem)
                            updateItem.Click()
                    } else {
                        WinActivate("ahk_exe Acrobat.exe")
                        Send("!h")
                        Sleep(150)
                        if (is2020)
                            Send("u")
                        else
                            Send("c")
                    }
                }
            } catch {
                ; Blind keyboard retry with alternative accelerator
                WinActivate("ahk_exe Acrobat.exe")
                Send("{Esc}")
                Sleep(100)
                if (isNewUI) {
                    Send("!h")
                    Sleep(150)
                    if (is2020)
                        Send("u")
                    else
                        Send("c")
                } else {
                    Send("!f")
                    Sleep(150)
                    Send("lc")
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
