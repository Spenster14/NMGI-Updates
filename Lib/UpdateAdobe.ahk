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
    WinMaximize("ahk_exe Acrobat.exe")
    WinWaitActive("ahk_exe Acrobat.exe",, 5)

    ; Allow UI to stabilize and dismiss modal overlays/tips
    Sleep(2000)
    Send("{Esc}")
    Sleep(500)
    WinActivate("ahk_exe Acrobat.exe")

    ; --- 3. Trigger Update Check via Help Menu ---
    UpdateStatus("Checking for Adobe updates...", 100, 100)
    triggered := false

    try {
        acrobatEl := UIA.ElementFromHandle("ahk_exe Acrobat.exe")
        helpItem := acrobatEl.FindElement({Name: "Help", Type: "MenuItem", Order: "LastToFirstOrder"})
        if (helpItem) {
            helpItem.Click()
            updateItem := acrobatEl.WaitElement({Name: "Check for Updates...", Type: "MenuItem", Order: "LastToFirstOrder"}, 3000)
            if (updateItem) {
                updateItem.Click()
                triggered := true
            }
        }
    }

    if (!triggered) {
        ; Keyboard accelerator fallback: Alt+H -> U
        WinActivate("ahk_exe Acrobat.exe")
        Send("!h")
        Sleep(600)
        Send("u")
    }

    ; --- 4. Wait for AdobeARM / Updater Window ---
    UpdateStatus("Waiting for Adobe Updater...", 100, 100)
    updaterFound := false

    loop 20 {
        if ProcessExist("AdobeARM.exe") || WinExist("ahk_exe AdobeARM.exe") || WinExist("Adobe Acrobat Updater") || WinExist("Adobe Acrobat 2020 Updater") {
            updaterFound := true
            break
        }
        Sleep(1000)
    }

    if (!updaterFound) {
        TerminateProcessGracefully("Acrobat.exe", 2, true)
        return " - Error (Updater window not found)"
    }

    ; --- 5. Monitor Update Status ---
    UpdateStatus("Monitoring Adobe update status...", 100, 100)
    startTime := A_TickCount
    updateResult := ""

    loop {
        ; Timeout after 3 minutes
        if (A_TickCount - startTime > 180000) {
            updateResult := " - Error (Updater timeout)"
            break
        }

        ; Check if updater closed on its own
        if !ProcessExist("AdobeARM.exe") && !WinExist("ahk_exe AdobeARM.exe") && !WinExist("Adobe Acrobat Updater") {
            if (updateResult == "")
                updateResult := " - No updates"
            break
        }

        armHwnd := WinExist("ahk_exe AdobeARM.exe") ? WinExist("ahk_exe AdobeARM.exe") : WinExist("Adobe Acrobat Updater")
        if (!armHwnd)
            armHwnd := WinExist("Adobe Acrobat 2020 Updater")

        if (armHwnd) {
            try {
                armEl := UIA.ElementFromHandle(armHwnd)

                ; Check for "No updates available"
                if armEl.FindElement({Name: "No updates available", mm: 2}) {
                    updateResult := " - No updates"
                    try armEl.FindElement({Name: "Close", Type: "Button", mm: 2}).Click()
                    break
                }

                ; Check for success states
                if armEl.FindElement({Name: "Update successful", mm: 2}) || armEl.FindElement({Name: "successful", mm: 2}) {
                    updateResult := " - Updates installed"
                    try armEl.FindElement({Name: "Close", Type: "Button", mm: 2}).Click()
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
                    try armEl.FindElement({Name: "Close", Type: "Button", mm: 2}).Click()
                    break
                }
            }
        }

        Sleep(1000)
    }

    ; --- 6. Post-execution Teardown ---
    TerminateProcessGracefully("AdobeARM.exe", 2, true)
    TerminateProcessGracefully("Acrobat.exe", 2, true)
    UpdateStatus()

    return (updateResult != "") ? updateResult : " - No updates"
}
