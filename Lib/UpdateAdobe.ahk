#Requires AutoHotkey v2.0
; Lib/UpdateAdobe.ahk - Adobe Acrobat orchestration module.
; Supports 64-bit and 32-bit Adobe Acrobat DC / Pro / 2020.

GetAdobePath() {
    ; 1. Authoritative desktop shortcuts (C:\Users\Public\Desktop\Applications, etc.)
    scPath := FindShortcutPath(["Acrobat.exe", "AcroRd32.exe"], ["(?i)Adobe\s*Acrobat|(?i)\bAcrobat\b|(?i)Adobe\s*Reader"])
    if (scPath != "")
        return scPath

    ; 2. Candidate local paths
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
        ; 1. Canonical Acrobat/Reader SDI main window class
        if (hwnd := WinExist("ahk_class AcrobatSDIWindow")) {
            adobeHwnd := hwnd
            break
        }
        ; 2. Modern Acrobat New Experience home title
        if (hwnd := WinExist("Welcome to Acrobat")) {
            adobeHwnd := hwnd
            break
        }
        ; 3. Title check (ensure we don't accidentally grab the trial modal)
        if (hwnd := WinExist("Adobe Acrobat")) {
            try {
                txt := WinGetText(hwnd)
                if (!InStr(txt, "free trial") && !InStr(txt, "Quit Adobe Acrobat")) {
                    adobeHwnd := hwnd
                    break
                }
            }
        }
        if (hwnd := WinExist("Acrobat Reader")) {
            adobeHwnd := hwnd
            break
        }
        ; 4. Process-based fallbacks
        if (hwnd := WinExist("ahk_exe Acrobat.exe")) {
            try {
                txt := WinGetText(hwnd)
                if (!InStr(txt, "free trial") && !InStr(txt, "Quit Adobe Acrobat")) {
                    adobeHwnd := hwnd
                    break
                }
            }
        }
        if (hwnd := WinExist("ahk_exe AcroRd32.exe")) {
            adobeHwnd := hwnd
            break
        }

        if ((A_TickCount - startTime) >= 20000)
            break
        Sleep(100)
    }

    if (!adobeHwnd) {
        return " - Error (Did not open)"
    }

    try WinActivate(adobeHwnd)
    DllCall("user32\SetForegroundWindow", "ptr", adobeHwnd)
    DllCall("user32\BringWindowToTop", "ptr", adobeHwnd)
    WinWaitActive(adobeHwnd,, 1)

    ; Immediately dismiss trial popup if already active
    DismissAdobeTrialPopup(adobeHwnd)

    ; --- 3. Instantly Trigger Update Check (Fast Path with UI Detection) ---
    UpdateStatus("Checking for Adobe updates...", 100, 100)

    ; Detect whether Acrobat is running Classic UI (Menu Bar) or Modern New Experience UI (Menu Button)
    is2020 := InStr(adobePath, "2020") ? true : false
    isClassicUI := true ; Default to Classic UI

    ; Instant Check 1: Win32 native MenuBar (0ms)
    hMenu := DllCall("user32\GetMenu", "ptr", adobeHwnd, "ptr")
    if (hMenu == 0) {
        isClassicUI := false
    }

    ; Instant Check 2: Title contains "Welcome to Acrobat" (Modern Home Screen)
    mainTitle := ""
    try mainTitle := WinGetTitle(adobeHwnd)
    if InStr(mainTitle, "Welcome to Acrobat") {
        isClassicUI := false
    }

    ; --- 4. Trigger Update Check & Wait for Updater (with 2-attempt retry) ---
    updaterFound := false

    loop 2 {
        attemptNum := A_Index
        UpdateStatus("Triggering Adobe update check (Attempt " . attemptNum . " of 2)...", 100, 100)

        ; Ensure trial popup is dismissed and main window is active
        DismissAdobeTrialPopup(adobeHwnd)
        try WinActivate(adobeHwnd)
        DllCall("user32\SetForegroundWindow", "ptr", adobeHwnd)
        Sleep(100)
        DismissAdobeTrialPopup(adobeHwnd)

        ; Trigger update menu
        if (isClassicUI) {
            ; Classic Acrobat DC / Pro / 2020 Menu Bar: Alt+H
            Send("!h")
            Sleep(150)
            if (is2020) {
                Send("u")
            } else {
                if (attemptNum == 1) {
                    Send("c")
                    Sleep(100)
                    Send("{Enter}")
                } else {
                    Send("u")
                    Sleep(100)
                    Send("{Enter}")
                }
            }
        } else {
            ; Modern Acrobat New Experience UI (Hamburger Menu)
            menuTriggered := false
            try {
                acrobatEl := UIA.ElementFromHandle(adobeHwnd)
                menuBtn := acrobatEl.FindElement({Name: "Menu", Type: "Button", mm: 2}, 2, 2)
                if (menuBtn) {
                    menuBtn.Click()
                    menuTriggered := true
                    Sleep(200)
                    rootEl := UIA.GetRootElement()
                    updateItem := rootEl.FindElement({Name: "(?i)check for updates", mm: "regex"}, 2, 3)
                    if (updateItem) {
                        updateItem.Click()
                    } else {
                        helpItem := rootEl.FindElement({Name: "(?i)help", mm: "regex"}, 2, 3)
                        if (helpItem) {
                            helpItem.Click()
                            Sleep(150)
                            updateItem2 := rootEl.FindElement({Name: "(?i)check for updates", mm: "regex"}, 2, 3)
                            if (updateItem2)
                                updateItem2.Click()
                        }
                    }
                }
            }

            if (!menuTriggered) {
                Send("!f")
                Sleep(150)
                Send("l")
                Sleep(150)
                Send("c")
                Sleep(100)
                Send("{Enter}")
            }
        }

        ; Wait up to 10 seconds (20 x 500ms) for Updater window
        UpdateStatus("Waiting for Adobe Updater (Attempt " . attemptNum . " of 2)...", 100, 100)
        loop 20 {
            ; Keep dismissing trial popup if it appears while waiting
            DismissAdobeTrialPopup(adobeHwnd)

            if WinExist("Adobe Acrobat Updater") || WinExist("Adobe Acrobat 2020 Updater") || WinExist("ahk_exe AdobeARM.exe") {
                updaterFound := true
                break 2 ; Success! Break out of both attempt and wait loops
            }

            ; Mid-wait fallback triggers
            if (A_Index == 6 && !updaterFound) {
                try WinActivate(adobeHwnd)
                DismissAdobeTrialPopup(adobeHwnd)
                if (isClassicUI) {
                    Send("{Esc}")
                    Sleep(100)
                    Send("!h")
                    Sleep(200)
                    Send("{Up}{Enter}")
                } else {
                    Send("{Esc}")
                    Sleep(100)
                    Send("!f")
                    Sleep(150)
                    Send("h")
                    Sleep(150)
                    Send("u")
                    Sleep(100)
                    Send("{Enter}")
                }
            }

            ; UIA desktop popup menu fallback
            if (A_Index == 10 && !updaterFound) {
                try {
                    updateItem := UIA.GetRootElement().FindElement({Name: "(?i)check for updates", mm: "regex"}, 2, 2)
                    if (updateItem)
                        updateItem.Click()
                }
            }

            Sleep(500)
        }

        ; If Attempt 1 failed to find updater, reset menu state, dismiss trial popups, and pause 1s
        if (!updaterFound && attemptNum < 2) {
            UpdateStatus("Adobe Updater not detected, retrying update check...", 100, 100)
            DismissAdobeTrialPopup(adobeHwnd)
            Send("{Esc}")
            Sleep(1000)
        }
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

; Detects and dismisses modal Adobe trial popups ("Start your free trial of Adobe Acrobat")
; Targets only child/popup dialogs without touching the main Acrobat window.
DismissAdobeTrialPopup(mainHwnd := 0) {
    found := false
    for h in WinGetList("Adobe Acrobat") {
        if (mainHwnd && h == mainHwnd)
            continue
        try {
            txt := WinGetText(h)
            if (InStr(txt, "free trial") || InStr(txt, "Start your free trial") || InStr(txt, "Quit Adobe Acrobat") || InStr(txt, "different Adobe ID")) {
                UpdateStatus("Dismissing Adobe trial popup...", 100, 100)
                WinActivate(h)
                Sleep(50)
                Send("{Esc}")
                Sleep(150)
                if !WinExist(h) {
                    found := true
                    continue
                }
                try ControlClick("Close", h,,,, "NA")
                Sleep(100)
                if !WinExist(h) {
                    found := true
                    continue
                }
                try WinClose(h)
                Sleep(100)
                found := true
            }
        }
    }
    return found
}
