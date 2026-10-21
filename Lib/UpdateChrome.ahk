#Requires AutoHotkey v2.0

GetChromePath() {
    if FileExist("C:\Program Files\Google\Chrome\Application\chrome.exe")
        return "C:\Program Files\Google\Chrome\Application\chrome.exe"
    else if FileExist("C:\Program Files (x86)\Google\Chrome\Application\chrome.exe")
        return "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
    return ""
}

Chrome(*)
{
	; --- 0. CLEANUP: Close existing instances ---
    if ProcessExist("chrome.exe") {
        UpdateStatus("Closing existing Chrome instances...", 100, 100)
        TerminateProcessGracefully("chrome.exe", 2, true)
        UpdateStatus() ; Clear tooltip
    }

    ; --- 1. Launch Chrome Normally ---
    chromePath := GetChromePath()
    if (chromePath = "") {
        MsgBox("Chrome not found.")
        return " - Error (Path not found)"
    }

    UpdateStatus("Launching Chrome...", 100, 100)
    Run(chromePath)
    
    UpdateStatus("Waiting for Chrome to open...", 100, 100)
    if !WinWait("ahk_exe chrome.exe",, 10) {
        return " - Error (Did not open)"
    }
    
    WinActivate("ahk_exe chrome.exe")
    WinMaximize("ahk_exe chrome.exe")
    WinWaitActive("ahk_exe chrome.exe")
    
    UpdateStatus("Waiting for Chrome to initialize...", 100, 100)
    ; Wait for UI to load, login screens to appear, and dismiss any focus-stealing bubbles
    Sleep(15000)
    Send("{Esc}")
    Sleep(500)
    Send("{Esc}")
    Sleep(500)
    
    WinActivate("ahk_exe chrome.exe") ; Ensure focus wasn't lost
    
    UpdateStatus("Navigating to Settings...", 100, 100)
    ; Navigate to settings page via a New Tab
    Send("^t")
    Sleep(1000)
    SendText("chrome://settings/help")
    Sleep(100)
    Send("{Enter}")
    
    ; Wait up to 5 seconds for the settings page title
    WinWait("Settings - About Chrome ahk_exe chrome.exe",, 5)

    ; --- 3. Monitor Update Status ---
    Loop {
        UpdateStatus("Checking Chrome status... " . A_Index, 100, 100)
        Sleep(1000)
        
        try {
            ; Re-acquire element in case the window refreshed
            chromeEl := UIA.ElementFromHandle("ahk_exe chrome.exe")
        } catch {
            continue
        }
            
        try {
            ; Check Success
            successEl := chromeEl.FindElement({Name:"Chrome is up to date", Type:"Text", MatchMode:"Substring"})
            if successEl {
                successEl.Highlight()
                UpdateStatus()
                TerminateProcessGracefully("chrome.exe", 2, true)
                return " - No updates"
            }
        } catch {
            ; Not found, continue
        }

        try {
            ; Check Restart
            relaunchBtn := chromeEl.FindElement({Name:"Nearly up to date", Type:"Text", MatchMode:"Substring"})
            if (relaunchBtn) {
                UpdateStatus("Relaunching Chrome...", 100, 100)
                pid := 0
                try pid := WinGetPID("ahk_exe chrome.exe")
                try {
                    btn := chromeEl.FindElement({Name:"Relaunch", Type:"Button", MatchMode:"Substring"})
                    btn.Highlight()
                    btn.Click()
                } catch {
                    WinClose("ahk_exe chrome.exe")
                }
                WinWaitClose("ahk_exe chrome.exe",, 10)
                if (pid)
                    ProcessWaitClose(pid)
                Sleep(3000)
				Chrome() 
                return " - Updates installed"
            }
        } catch {
            ; Keep looping
        }

        if (A_Index > 500) {
            UpdateStatus()
            TerminateProcessGracefully("chrome.exe", 2, true)
            return " - Error (Timeout)"
        }
    }
}