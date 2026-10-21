#Requires AutoHotkey v2.0

GetFirefoxPath() {
    if FileExist("C:\Program Files\Mozilla Firefox\firefox.exe")
        return "C:\Program Files\Mozilla Firefox\firefox.exe"
    else if FileExist("C:\Program Files (x86)\Mozilla Firefox\firefox.exe")
        return "C:\Program Files (x86)\Mozilla Firefox\firefox.exe"
    return ""
}

Firefox(*)
{
    ; --- 0. CLEANUP: Close existing instances ---
    if ProcessExist("firefox.exe") {
        UpdateStatus("Closing existing Firefox instances...", 100, 100)
        TerminateProcessGracefully("firefox.exe", 2, true)
        UpdateStatus()
    }

    ; --- 1. Launch Firefox ---
    ffPath := GetFirefoxPath()
    if (ffPath = "") {
        MsgBox("Firefox not found.")
        return " - Error (Path not found)"
    }

    UpdateStatus("Launching Firefox...", 100, 100)
    Run(ffPath)
    
    UpdateStatus("Waiting for Firefox to open...", 100, 100)
    if !WinWait("ahk_exe firefox.exe",, 10)
        return " - Error (Did not open)"
        
    WinActivate("ahk_exe firefox.exe")
    WinMaximize("ahk_exe firefox.exe")
    WinWaitActive("ahk_exe firefox.exe")
    UpdateStatus("Waiting for Firefox to initialize...", 100, 100)
    Sleep(15000)

    ; --- 2. Navigate to "About Firefox" ---
    UpdateStatus("Navigating to 'About Firefox'...", 100, 100)
    try {
        WinActivate("ahk_exe firefox.exe")
        Sleep(500)
        
        ; Escape captive login screens/portals by opening a new tab first
        Send("^t")
        Sleep(1000)
        
        ; First try the universally standard keyboard shortcut (Alt+H opens Help menu, A opens About)
        ; This is much more reliable than clicking the Hamburger menu which changes layout often.
        Send("!h")
        Sleep(300)
        Send("a")
        
        ; Check if it worked
        if !WinWait("About Mozilla Firefox",, 2) {
            ; Fallback to UI Automation if keyboard shortcuts failed (e.g. menu locked)
            ffEl := UIA.ElementFromHandle("ahk_exe firefox.exe")
            
            try {
                ffEl.WaitElement({Name:"Open application menu", MatchMode:"Substring", Type:"Button"}, 3000).Click()
            } catch {
                ; Sometime it's called Firefox in older trees
                try ffEl.WaitElement({Name:"Firefox", MatchMode:"Substring", Type:"Button"}, 2000).Click()
            }
            Sleep(500)

            try ffEl.WaitElement({Name:"Help", MatchMode:"Substring"}, 2000).Click()
            Sleep(500)
            
            try ffEl.WaitElement({Name:"About Firefox", MatchMode:"Substring"}, 2000).Click()
            
            WinWait("About Mozilla Firefox",, 5)
        }
        
        WinActivate("About Mozilla Firefox")

    } catch as err {
        MsgBox("Firefox Navigation Error: " . err.Message)
        return " - Error (Nav)"
    }

    ; --- 3. Monitor Update Status ---
    Loop {
        UpdateStatus("Checking Firefox status... " . A_Index, 100, 100)
        Sleep(1000)
        
        try {
            ; Get the handle for the POPUP window specifically
            aboutEl := UIA.ElementFromHandle("About Mozilla Firefox")
            
            ; CASE A: Success ("Firefox is up to date")
            ; We search for text containing "up to date"
            try {
                if aboutEl.FindElement({Name:"Firefox is up to date", Type:"Group", MatchMode:"Substring"}).Highlight() {
                    UpdateStatus()
                    try WinClose("About Mozilla Firefox")
                    TerminateProcessGracefully("firefox.exe", 2, true)
                    return " - No updates"
                }
            }

            ; CASE B: Restart Required ("Restart to update Firefox")
            ; This is usually a BUTTON, not just text
            try {
                restartBtn := aboutEl.FindElement({Name:"Restart to update", Type:"Button", MatchMode:"Substring"})
                if (restartBtn) {
                    UpdateStatus("Restarting Firefox...", 100, 100)
                    pid := 0
                    try pid := WinGetPID("ahk_exe firefox.exe")
                    restartBtn.Click()
                    
                    ; Wait for it to close
                    WinWaitClose("ahk_exe firefox.exe")
                    if (pid)
                        ProcessWaitClose(pid)
                    Sleep(3000)
                    
                    ; Recursive Call: Verify the update worked
					Firefox()
                    return " - Updates installed"
                }
            }

            ; CASE C: Update Available ("Update to")
            try {
                updateBtn := aboutEl.FindElement({AutomationId:"downloadAndInstallButton", Type:"Button"})
                if (updateBtn) {
                    UpdateStatus("Starting update...", 100, 100)
                    updateBtn.Click()
                    Sleep(2000)
                }
            } catch {
            }

            ; CASE D: Downloading/Applying ("Applying update..." or "Downloading update")
            try {
                if aboutEl.FindElement({Name:"Downloading update", MatchMode:"Substring"}) {
                    UpdateStatus("Downloading Firefox update...", 100, 100)
                }
                else if aboutEl.FindElement({Name:"Applying update", MatchMode:"Substring"}) {
                    UpdateStatus("Applying Firefox update...", 100, 100)
                }
            } catch {
            }
            
        } catch {
            ; Elements might not be loaded yet
        }
        
        ; Safety Break: 500 seconds
        if (A_Index > 500) {
            UpdateStatus()
            try WinClose("About Mozilla Firefox")
            TerminateProcessGracefully("firefox.exe", 2, true)
            return " - Error (Timeout)"
        }
    }
}