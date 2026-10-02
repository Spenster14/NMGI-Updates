#Requires AutoHotkey v2.0

GetUTPath(UTversion) {
    possiblePaths := [
        "\\Tho1\thomson\WINCSI\UT" . UTversion . "\utw" . UTversion . ".exe",
        "\\przfsapp1\WinCSI\UT" . UTversion . "\utw" . UTversion . ".exe",
        "\\swtho1\WinCSI\UT" . UTversion . "\utw" . UTversion . ".exe",
        "\\kmitho1\WinCSI\UT" . UTversion . "\utw" . UTversion . ".exe",
        "W:\UT" . UTversion . "\utw" . UTversion . ".exe",
        "W:\WinCSI\UT" . UTversion . "\utw" . UTversion . ".exe",
        "P:\WinCSI\UT" . UTversion . "\utw" . UTversion . ".exe",
        "S:\WinCSI\UT" . UTversion . "\utw" . UTversion . ".exe",
        "C:\WinCSI\UT" . UTversion . "\utw" . UTversion . ".exe"
    ]

    for path in possiblePaths {
        if (UTversion == "23" && (InStr(path, "\\kmitho1") || InStr(path, "\\swtho1"))) {
            continue
        }
        if FileExist(path) {
            return path
        }
    }
    return ""
}

UT(UTversion, PostUpdate := false) {
    ; --- 1. Launch UltraTax (Only if not post-update) ---
    if (!PostUpdate) {
        foundPath := GetUTPath(UTversion)

        ; Run or Error
        if (foundPath) {
            Run(foundPath)
        } else {
            MsgBox("Error: UltraTax " . UTversion . " executable not found in defined locations.")
            return " - Error (Path not found)"
        }

        TRLogin() ; Login helper
    }

    WinWait("UltraTax CS")
    WinActivate("UltraTax CS")
    WinMaximize("UltraTax CS")
    Sleep(1000)

    ; Clean up startup popups
    HandleBulletins()

    ; --- 2. Navigate to CS Connect ---
    try {
        UpdateStatus("Waiting for CS Connect button...", 100, 100)
        btn := ""
        loop 60 { ; Try for up to 120 seconds (2s sleeps)
            ; Aggressively clear late-spawning popups (like slow-loading PDFs)
            if WinExist("User Bulletin") {
                try WinActivate("User Bulletin")
                try {
                    UIA.ElementFromHandle("User Bulletin").FindElement({ Name: "Close", Type: "Button" }).Click()
                } catch {
                    WinClose("User Bulletin")
                }
            }
            if WinExist("User already present") {
                try WinActivate("User already present")
                try {
                    UIA.ElementFromHandle("User already present").FindElement({ Name: "OK", Type: "Button" }).Click()
                } catch {
                    Send("{Enter}")
                }
            }
            if WinExist("Choose Data Location") {
                try WinActivate("Choose Data Location")
                try {
                    UIA.ElementFromHandle("Choose Data Location").FindElement({ Name: "OK", Type: "Button" }).Click()
                } catch {
                    Send("{Enter}")
                }
            }

            try {
                if WinExist("UltraTax CS") {
                    ; Get the main window element
                    utEl := UIA.ElementFromHandle("UltraTax CS")
                    ; FindElement scans the UI tree exactly once without timing out prematurely
                    btn := utEl.FindElement({ Name: "CS Connect (Ctrl+K)", Type: "Button" })

                    if btn {
                        btn.Click()
                        break
                    }
                }
            } catch {
                ; Ignore exceptions (like unready UI tree or disabled controls) and retry
            }
            Sleep(2000)
        }
        UpdateStatus()

        if !btn {
            MsgBox("Timed out waiting or trying to click 'CS Connect' button after 120 seconds.")
            return " - Error (CS Connect Timeout)"
        }

        ; Wait for CS Connect window to appear
        if !WinWait("CS Connect", , 120) {
            MsgBox("Timed out waiting for 'CS Connect' window to appear inside UltraTax after 120 seconds.")
            return " - Error (CS Connect Timeout)"
        }

        try {
            UIA.ElementFromHandle("CS Connect").WaitElement({ Name: "Connect", Type: "Button" }, 15000).Click()
        } catch {
            ; Fallback: Send Enter in case it's the default button and UI Automation fails to find it
            WinActivate("CS Connect")
            Sleep(500)
            Send("{Enter}")
        }

        ; Wait for Call Summary (give it up to 5 minutes as it might optionally be downloading)
        if !WinWait("Call Summary", , 300) {
            MsgBox("Timed out waiting for 'Call Summary' window to appear.")
            return " - Error (Call Summary Timeout)"
        }

        ; Read the document text inside Call Summary
        ; Added a short sleep to ensure the document content is fully populated before reading
        Sleep(2000)
        try {
            callSumEl := UIA.ElementFromHandle("Call Summary")
            docText := callSumEl.WaitElement({ LocalizedType: "document", Type: "Document" }, 15000).Value
        } catch as err {
            MsgBox("Failed to read 'Document' within Call Summary window: " . err.Message)
            return " - Error (Document Read UI)"
        }
    } catch as err {
        MsgBox("General UI Error during CS Connect process: " . err.Message)
        return " - Error (UI)"
    }

    ; --- 3. Check Update Status ---

    ; CASE A: No Updates Found
    if InStr(docText, "No new updates") {
        try callSumEl.FindElement({ Name: "Close", Type: "Button" }).Click()
        WinClose("UltraTax CS")

        if (PostUpdate)
            return ; Void return for post-update check
        else
            return " - No updates"
    }

    ; CASE B: Updates Applied (Restart Required)
    else {
        UpdateStatus("Testing update...", 100, 100)

        ; Close Call Summary to trigger restart prompt
        try callSumEl.FindElement({ Name: "Close", Type: "Button" }).Click()

        UpdateStatus("Waiting for Restart popup", 100, 100)
        WinWait("UltraTax CS", "Updates have been applied")

        UpdateStatus("Clicking OK to restart...", 100, 100)
        try {
            UIA.ElementFromHandle("UltraTax CS").WaitElement({ Name: "OK", Type: "Button" }).Click()
        } catch {
            Send("{Enter}") ; Fallback if UIA fails on simple dialog
        }
        UpdateStatus()

        ; Wait for restart cycle
        WinWaitClose("UltraTax CS")
        WinWait("UltraTax CS")
        WinActivate("UltraTax CS")
        WinMaximize("UltraTax CS")

        ; Handle post-restart popups
        HandleBulletins(10) ; Check 10 times for post-update bulletins

        WinClose("UltraTax CS")
        return " - Updates installed"
    }
}

/* UT(UTversion, PostUpdate:=0)
{
	If !PostUpdate {
		switch UTversion
		{
			case "21":
				Run "C:\WinCSI\UT21\utw21.exe"
			case "22":
				Run "C:\WinCSI\UT22\utw22.exe"
			case "23":
				Run "C:\WinCSI\UT23\utw23.exe"
			case "24":
				{
					if FileExist("C:\WinCSI\UT24\utw24.exe")
						Run "C:\WinCSI\UT24\utw24.exe"
					else
						Run "W:\UT24\utw24.exe"
				}
			case "25":
				{
					if FileExist("C:\WinCSI\UT25\utw25.exe")
						Run "C:\WinCSI\UT25\utw25.exe"
					else
						Run "W:\UT25\utw25.exe"
				}
		}

		TRLogin()
	}

	WinActivate "UltraTax CS"
	WinMaximize
	WinClose "Onvio"

	Loop 5{
		Sleep(1000)
		if WinExist("User Bulletin")
		{
			WinActive "User Bulletin"
			UIA.ElementFromHandle("User Bulletin").FindElement({Name:"Close", Type:"Button"}).Click()
		}
	}
	UIA.ElementFromHandle("UltraTax CS").WaitElement({Name:"CS Connect (Ctrl+K)", Type:"Button"}).Click()
	WinWait "CS Connect"
	UIA.ElementFromHandle("CS Connect").WaitElement({Name:"Connect", Type:"Button"}).Click()
	WinWait "Call Summary"
	if (InStr(UIA.ElementFromHandle("Call Summary").FindElement({LocalizedType:"document", Type:"Document"}).Value, "No new updates", false) && PostUpdate)
	{
		UIA.ElementFromHandle("Call Summary").FindElement({Name:"Close", Type:"Button"}).Highlight().Click()
		WinClose "UltraTax"
		return
	}
	if InStr(UIA.ElementFromHandle("Call Summary").FindElement({LocalizedType:"document", Type:"Document"}).Value, "No new updates", false)
	{
		UIA.ElementFromHandle("Call Summary").FindElement({Name:"Close", Type:"Button"}).Highlight().Click()
		WinClose "UltraTax"
		return " - No updates"
	}
	else
	{
		;  MsgBox "Not no new updates, something else!  Exiting. Handle manually"							;  Need logic here for when there are updates
		;  Test Stuff
		UpdateStatus("Testing update...", 100, 100)
		UIA.ElementFromHandle("Call Summary").FindElement({Name:"Close", Type:"Button"}).Highlight().Click()
		UpdateStatus("Waiting for Restart popup", 100, 100)
		WinWait("UltraTax CS","Updates have been applied.  Restart UltraTax CS to complete the update process.")
		UpdateStatus("Waiting for OK button click", 100, 100)
		UIA.ElementFromHandle("UltraTax CS").WaitElement({Name:"OK", Type:"Button"}).Highlight().Click()
		ToolTip
		WinWaitClose "UltraTax CS"
		WinWaitActive "UltraTax CS"
		WinMaximize
		Loop 10{
			Sleep(1000)
			if WinExist("User Bulletin")
			{
				WinActive "User Bulletin"
				UIA.ElementFromHandle("User Bulletin").FindElement({Name:"Close", Type:"Button"}).Click()
			}
		}
		WinClose "UltraTax"
		return " - Updates installed"
	}
} */
