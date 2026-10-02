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
        try {
            if WinExist("ahk_exe firefox.exe")
                WinClose("ahk_exe firefox.exe")
            
            ; Wait 2 seconds for graceful close
            ProcessWaitClose("firefox.exe", 2)
            if ProcessExist("firefox.exe") {
                RunWait("taskkill /F /IM firefox.exe /T",, "Hide")
            }
        }
        UpdateStatus()
    }

    ; --- 1. Launch Firefox ---
    ffPath := GetFirefoxPath()
    if (ffPath = "") {
        MsgBox("Firefox not found.")
        return " - Error"
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
                    WinClose("About Mozilla Firefox")
                    if WinExist("ahk_exe firefox.exe")
                        WinClose("ahk_exe firefox.exe")
                    ProcessWaitClose("firefox.exe", 2)
                    if ProcessExist("firefox.exe")
                        RunWait("taskkill /F /IM firefox.exe /T",, "Hide")
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
            WinClose("About Mozilla Firefox")
            if WinExist("ahk_exe firefox.exe")
                WinClose("ahk_exe firefox.exe")
            ProcessWaitClose("firefox.exe", 2)
            if ProcessExist("firefox.exe")
                RunWait("taskkill /F /IM firefox.exe /T",, "Hide")
            return " - Error (Timeout)"
        }
    }
}

/* Firefox(*)
{
	cfirefoxupdateEl:=""
	Run "C:\Program Files\Mozilla Firefox\firefox.exe"
	WinWaitActive "Firefox"
	WinMaximize "Firefox"
	while !(WinGetMinMax("Firefox")=="1")
	{
		Sleep 250
		WinMaximize "Firefox"
	}
	Sleep 1000
	cfirefoxEl := UIA.ElementFromHandle("A")
	cfirefoxEl.WaitElement({Name:"Firefox", Type:"Button", Order:"LastToFirstOrder"}).Click()
	cfirefoxEl.WaitElement({Name:"Help", Type:"Button", Order:"LastToFirstOrder"}).Click()
	cfirefoxEl.WaitElement({Name:"About Firefox", Type:"Button", Order:"LastToFirstOrder"}).Click()
	WinWait "About Mozilla Firefox"
	WinActivate "About Mozilla Firefox"
	Sleep 1000
	Loop {
		Mousemove(50, 50, 0)
		result := OCR.FromWindow("About Mozilla Firefox",,2)
		Loop result.Lines.Length{
			if InStr(result.Lines[A_Index].Text, "64-bit", false)
			StatusLine := A_Index - 1
		}
		try resultline := result.Lines[StatusLine].Text
		catch
		{
			continue
		}
		if InStr(resultline, "Firefox is up", false)
		{
			result.Highlight(result.Lines[StatusLine])
			WinClose "Firefox"
			WinClose "Firefox"
			FileAppend("- Firefox - No updates`r`n",TodayDate . "-Update.log")
			return
		}
		else if InStr(resultline, "Update to", false)
		{
			;  Need logic for pushing the button here.
			result.Highlight(result.Lines[StatusLine])   ; Untested!
			resultToClick := result.FindString(result.Lines[StatusLine].Text)
			result.Click(resultToClick, "left", 1)   ; Untested!
			Sleep 1000
		}
		else if InStr(resultline, "Restart to", false)
		{
			WinClose "Firefox"
			WinClose "Firefox"
			Sleep 2000
			Firefox()
			RemoveOutput("Firefox")
			FileAppend("- Firefox - Updates installed`r`n",TodayDate . "-Update.log")
			return
		}
		Sleep 100
	}
} */