#Requires AutoHotkey v2.0

GetEdgePath() {
    ; 1. Authoritative desktop shortcuts (C:\Users\Public\Desktop\Applications, etc.)
    scPath := FindShortcutPath("msedge.exe", ["(?i)Microsoft\s*Edge|(?i)\bEdge\b"])
    if (scPath != "")
        return scPath

    ; 2. Candidate local paths
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
        TerminateProcessGracefully("msedge.exe", 2, true)
        UpdateStatus()
    }

    ; --- 1. Launch Edge Normally ---
    edgePath := GetEdgePath()
    if (edgePath = "") {
        MsgBox("Edge not found.")
        return " - Error (Path not found)"
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
                TerminateProcessGracefully("msedge.exe", 2, true)
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
            TerminateProcessGracefully("msedge.exe", 2, true)
            return " - Error (Timeout)"
        }
    }
}