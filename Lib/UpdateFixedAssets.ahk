#Requires AutoHotkey v2.0

GetFixedAssetsPath() {
    potentialPaths := [
        "\\chfsapp1\WINCSI\DSW\dsw.exe",
        "X:\DSW\DSW.exe",
        "U:\WinCSI\DSW\dsw.exe",
        "\\hfaapp1\WINCSI\FA25\DSW\dsw.exe",
        "\\app1\WinCSI\DSW\dsw.exe",
        "W:\WinCSI\DSW\dsw.exe",
        "\\goserver\Y\WinCSI\DSW\dsw.exe",
        "C:\WinCSI\DSW\dsw.exe"
    ]

    for index, path in potentialPaths {
        if FileExist(path) {
            return path
        }
    }
    return ""
}

FixedAssets(PostUpdate := false) {
    ; --- 1. Launch / Activate -------------------------------------------------
    if (!PostUpdate) {
        faPath := GetFixedAssetsPath()
        if (faPath = "") {
            MsgBox("Error: Fixed Assets executable not found in any specified location.")
            return " - Error"
        }
        Run(faPath)

        TRLogin() ; Initial Login
    }

    WinWait("Fixed Assets CS")
    WinActivate("Fixed Assets CS")
    WinMaximize("Fixed Assets CS")

    ; Clean up startup popups (Onvio / User Bulletin)
    HandleBulletins()

    ; --- 2. Navigate to CS Connect --------------------------------------------
    try {
        faEl := UIA.ElementFromHandle("Fixed Assets CS")

        ; Click the specific "CS Connect" tool button (the red plug icon)
        ; We use a 60-second timeout because the application takes a long time to fully build its UI tree.
        faEl.WaitElement({ Name: "CS Connect", Type: "Button" }, 60000).Click()

        WinWait("CS Connect")
        UIA.ElementFromHandle("CS Connect").WaitElement({ Name: "Connect", Type: "Button" }).Click()

        WinWait("Call Summary")
        callSumEl := UIA.ElementFromHandle("Call Summary")

        ; Read Status
        statusText := callSumEl.WaitElement({ Type: "Document" }).Value

    } catch as err {
        MsgBox("UI Error during CS Connect: " . err.Message)
        return " - Error (UI)"
    }

    ; --- 3. Check Update Status -----------------------------------------------

    ; CASE A: No Updates
    if InStr(statusText, "No new updates") {
        try callSumEl.FindElement({ Name: "Close", Type: "Button" }).Highlight().Click()
        Sleep(500)
        WinClose("Fixed Assets CS")
        return " - No updates"
    }

    ; CASE B: Updates Found
    else {
        UpdateStatus("Updates detected... applying.", 100, 100)

        ; Close Call Summary to trigger the Apply/Restart flow
        try callSumEl.FindElement({ Name: "Close", Type: "Button" }).Click()

        ; Handle Restart Prompt
        ; The popup window is actually named 'UltraTax CS' despite being for Fixed Assets
        pid := 0
        try pid := WinGetPID("Fixed Assets CS")
        if WinWait("UltraTax CS", "Updates have been applied", 5) {
            try UIA.ElementFromHandle("UltraTax CS").WaitElement({ Name: "OK", Type: "Button" }).Click()
            catch {
                WinActivate("UltraTax CS")
                Send("{Enter}")
            }
        }

        UpdateStatus("Waiting for Fixed Assets to restart...", 100, 100)
        WinWaitClose("Fixed Assets CS")
        if (pid)
            ProcessWaitClose(pid)

        ; Wait for App to Reload
        WinWait("Fixed Assets CS")
        WinActivate("Fixed Assets CS")

        ; Fixed Assets usually requires re-login after a restart
        TRLogin()

        ; Recursive Call: Verify the update is finished
        ; We pass 'true' so it skips the initial Run command
        FixedAssets(true)
        return " - Updates installed"
    }
}

/* FixedAssets(PostUpdate:=0)
{
	found:=""
	Run "C:\WinCSI\DSW\dsw.exe"
	TRLogin()
	WinActivate "Fixed Assets CS"
	if PostUpdate
	{
		WinWaitActive "User Bulletin"
		UIA.ElementFromHandle("User Bulletin").FindElement({Name:"Close", Type:"Button"}).Click()
	}
	WinWaitActive "Fixed Assets CS"
	WinClose "Onvio"
	;~ Sleep 30000														;  Don't love this.  Need to find quicker solution. Program slow to load
	; WinMinimize "Fixed Assets CS"
	; WinMaximize "Fixed Assets CS"
	while !(WinGetMinMax("Fixed Assets CS")=="1")
	{
		Sleep 250
	}
	WinActivate "Fixed Assets CS"
	Sleep 5000
	UIA.ElementFromHandle("Fixed Assets CS").WaitElement({Name:"CS Connect", Type:"Button"}).Click()
	WinWait "CS Connect"
	UIA.ElementFromHandle("CS Connect").WaitElement({Name:"Connect", Type:"Button"}).Click()
	WinWait "Call Summary"
	if (InStr(UIA.ElementFromHandle("Call Summary").WaitElement({Type:"Document"}).Value, "No new updates", false) && PostUpdate)
	{
		return
	}
	if InStr(UIA.ElementFromHandle("Call Summary").WaitElement({Type:"Document"}).Value, "No new updates", false)
	{
		UIA.ElementFromHandle("Call Summary").FindElement({Name:"Close", Type:"Button"}).Highlight().Click()
		WinClose "Fixed Assets CS"
		FileAppend("- Fixed Assets - No updates`r`n",TodayDate . "-Update.log")
		return
	}
	else
	{
		;  MsgBox "Not no new updates, something else!  Exiting. Handle manually"							;  Need logic here for when there are updates
		;  Test Stuff
		UpdateStatus("Testing update...", 100, 100)
		UIA.ElementFromHandle("Call Summary").FindElement({Name:"Close", Type:"Button"}).Highlight().Click()
		UpdateStatus("Waiting for Restart popup", 100, 100)
		WinWait("UltraTax CS","Updates have been applied.  Restart Fixed Assets CS to complete the update process.")
		UpdateStatus("Waiting for OK button click", 100, 100)
		UIA.ElementFromHandle("UltraTax CS").WaitElement({Name:"OK", Type:"Button"}).Highlight().Click()
		ToolTip
		WinWaitClose "Fixed Assets CS"
		WinWaitActive "Fixed Assets CS"
		WinMaximize
		TRLogin()
		Loop 10{
			Sleep(1000)
			if WinExist("User Bulletin")
			{
				WinActive "User Bulletin"
				UIA.ElementFromHandle("User Bulletin").FindElement({Name:"Close", Type:"Button"}).Click()
			}
		}
		WinClose "Fixed Assets CS"
		FileAppend("- Fixed Assets - Updates installed`r`n",TodayDate . "-Update.log")
		return
	}
} */
