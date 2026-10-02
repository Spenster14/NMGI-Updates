#Requires AutoHotkey v2.0

GetEdgePath() {
    if FileExist("C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")
        return "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    else if FileExist("C:\Program Files\Microsoft\Edge\Application\msedge.exe")
        return "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    return ""
}

Edge(*)
{
	; --- 0. CLEANUP: Close existing instances ---
    if ProcessExist("msedge.exe") {
        UpdateStatus("Closing existing Edge instances...", 100, 100)
        try {
            ; Try gentle close first
            if WinExist("ahk_exe msedge.exe")
                WinClose("ahk_exe msedge.exe")
            
            ; Wait 2 seconds for it to close gracefully
            ProcessWaitClose("msedge.exe", 2)
            if ProcessExist("msedge.exe") {
                ; If still running, force kill
                RunWait("taskkill /F /IM msedge.exe /T",, "Hide")
            }
        }
        UpdateStatus()
    }

    ; --- 1. Launch Edge Normally ---
    edgePath := GetEdgePath()
    if (edgePath = "") {
        MsgBox("Edge not found.")
        return " - Error"
    }

    UpdateStatus("Launching Edge...", 100, 100)
    Run(edgePath)
    
    UpdateStatus("Waiting for Edge to open...", 100, 100)
    if !WinWait("ahk_exe msedge.exe",, 10)
        return " - Error (Did not open)"
        
    WinActivate("ahk_exe msedge.exe")
    WinMaximize("ahk_exe msedge.exe")
    WinWaitActive("ahk_exe msedge.exe")
    
    UpdateStatus("Navigating to Settings...", 100, 100)
    ; Wait for UI to load and dismiss any focus-stealing bubbles
    Sleep(2000)
    Send("{Esc}")
    Sleep(500)
    Send("{Esc}")
    Sleep(500)
    
    WinActivate("ahk_exe msedge.exe") ; Ensure focus wasn't lost
    
    ; Navigate to settings page via a New Tab
    Send("^t")
    Sleep(500)
    SendText("edge://settings/help")
    Sleep(100)
    Send("{Enter}")
    
    ; Wait up to 5 seconds for the settings page title
    WinWait("Settings",, 5)

    ; --- 3. Monitor Update Status ---
    Loop {
        UpdateStatus("Checking Edge status... " . A_Index, 100, 100)
        Sleep(1000)
        
        try {
            edgeEl := UIA.ElementFromHandle("ahk_exe msedge.exe")
        } catch {
            continue
        }

        try {
            ; Check Success
            successEl := edgeEl.FindElement({Name:"Microsoft Edge is up to date", Type:"Text", MatchMode:"Substring"})
            if successEl {
                successEl.Highlight()
                UpdateStatus()
                if WinExist("ahk_exe msedge.exe")
                    WinClose("ahk_exe msedge.exe")
                ProcessWaitClose("msedge.exe", 2)
                if ProcessExist("msedge.exe")
                    RunWait("taskkill /F /IM msedge.exe /T",, "Hide")
                return " - No updates"
            }
        } catch {
            ; Not found, continue
        }

        try {
            ; Check Updates Underway
            underwayMsg := edgeEl.FindElement({Name:"Updates are underway", Type:"Text", MatchMode:"Substring"})
            if (underwayMsg) {
                UpdateStatus("Updates underway. Closing Edge, waiting 10s, then relaunching...", 100, 100)
                pid := 0
                try pid := WinGetPID("ahk_exe msedge.exe")
                try WinClose("ahk_exe msedge.exe")
                WinWaitClose("ahk_exe msedge.exe",, 10)
                if (pid)
                    ProcessWaitClose(pid)
                Sleep(10000) ; Wait 10 seconds
                Edge()
                return " - Updates installed"
            }
        } catch {
            ; Not found, continue
        }

        try {
            ; Check Restart
            relaunchMsg := edgeEl.FindElement({Name:"To finish updating", Type:"Text", MatchMode:"Substring"})
            if (relaunchMsg) {
                UpdateStatus("Relaunching Edge...", 100, 100)
                pid := 0
                try pid := WinGetPID("ahk_exe msedge.exe")
                try {
                    btn := edgeEl.FindElement({Name:"Restart", Type:"Button", MatchMode:"Substring"})
                    btn.Highlight()
                    btn.Click()
                } catch {
                    WinClose("ahk_exe msedge.exe")
                }
                WinWaitClose("ahk_exe msedge.exe",, 10)
                if (pid)
                    ProcessWaitClose(pid)
                Sleep(3000)
				Edge()
                return " - Updates installed"
            }
        } catch {
            ; Keep looping
        }
        
        if (A_Index > 500) {
            UpdateStatus()
            if WinExist("ahk_exe msedge.exe")
                WinClose("ahk_exe msedge.exe")
            ProcessWaitClose("msedge.exe", 2)
            if ProcessExist("msedge.exe")
                RunWait("taskkill /F /IM msedge.exe /T",, "Hide")
            return " - Error (Timeout)"
        }
    }
}

/* Edge(*)
{
	Run "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
	WinWaitActive "Edge"
	WinMaximize "Edge"
	while !(WinGetMinMax("Edge")=="1")
	{
		Sleep 250
		WinMaximize "Edge"
	}
	edgeEl := UIA.ElementFromHandle("ahk_exe msedge.exe")
	Sleep 1000		
	try {
		edgeEl.FindElement({Name:"Settings and more (Alt+F)", Type:"Button"}).ControlClick()
		Sleep(250)
		edgeEl.FindElement({Name:"Help and feedback", Type:"MenuItem"}).Click()
		Sleep(250)
		edgeEl.FindElement({Name:"About Microsoft Edge", Type:"MenuItem"}).Click()
	} catch Error as e {
		Send("!f")
		Sleep 250
		Send("bm")
	}
	Sleep 1000

	Loop {
		edgeEl := UIA.ElementFromHandle("ahk_exe msedge.exe")
		UpdateStatus("Waiting to Uptodate or reboot message", 100, 100)
		try {
			edgeEl.FindElement({Name:"Microsoft Edge is up to date.", Type:"Text"}).Highlight()
		} catch Error as e {
			; did not find the Button
		} else {
			MsgBox("Found up to date.", "Status", "T0.5")
			UpdateStatus()
			WinClose "Edge"
			return " - No updates"
		}
		try {
			edgeEl.FindElement({Name:"REPLACE ME WITH PROPER INFOChrome to finish updating.", Type:"Text"}).Highlight()
		} catch Error as e {
			; did not find the menuItem
		} else {
			WinClose "Edge"
			Sleep(3000)
			Edge()
			Sleep(1000)
			return " - Updates installed"
		}
		Sleep 100
	}
} */