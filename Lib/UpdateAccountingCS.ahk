#Requires AutoHotkey v2.0

GetAccountingCSPath() {
    potentialPaths := [
        "W:\Creative Solutions\Accounting CS\AccountingCS.exe",
        "X:\Creative Solutions\Accounting CS\AccountingCS.exe",
        "P:\Creative Solutions\Accounting CS\AccountingCS.exe",
        "S:\Creative Solutions\Accounting CS\AccountingCS.exe",
        "C:\Program Files (x86)\Creative Solutions\Accounting CS\AccountingCS.exe",
        "C:\Program Files\Creative Solutions\Accounting CS\AccountingCS.exe"
    ]

    for index, path in potentialPaths {
        if FileExist(path) {
            return path
        }
    }
    return ""
}

AccountingCS(PostUpdate := false) {
    ; --- 1. Launch / Activate -------------------------------------------------
    if (!PostUpdate) {
        acsPath := GetAccountingCSPath()
        if (acsPath = "") {
            MsgBox("Error: Accounting CS executable not found in any specified location.")
            return " - Error"
        }
        Run(acsPath)

        TRLogin() ; Initial Login
    }

    ;UpdateStatus("Waiting for Accounting CS to load...", 100, 100)
    WinWait("Accounting CS")
    WinActivate("Accounting CS")
    WinMaximize("Accounting CS")
    UpdateStatus("Waiting for Accounting CS to load...", 100, 100)

    UpdateStatus("Waiting for user to enter password and Accounting CS dashboard to load...", 100, 100)

    ; Wait indefinitely for the main dashboard to appear (which means login is complete)
    WinWait("Accounting CS -")
    WinActivate("Accounting CS -")
    WinMaximize("Accounting CS -")

    UpdateStatus()

    ; Clean up startup popups (Onvio / User Bulletin)
    HandleBulletins()
    ; --- 2. Navigate to CS Connect --------------------------------------------
    WinWaitActive("Accounting CS -")
    try {
        acsEl := UIA.ElementFromHandle("Accounting CS -")

        UpdateStatus("Waiting for Accounting CS Connect button...", 100, 100)
        btn := ""
        loop 30 {
            try {
                if WinExist("Accounting CS -") {
                    acsEl := UIA.ElementFromHandle("Accounting CS -")
                    btn := acsEl.FindElement({ Name: "CS Connect", MatchMode: "Substring" })
                    if btn {
                        break
                    }
                }
            }
            Sleep(1000)
        }

        if !btn {
            FileAppend(acsEl.DumpAll(), A_ScriptDir . "\AccountingCS_Dump.txt")
            MsgBox("Could not find CS Connect element. UIA Tree dumped to AccountingCS_Dump.txt")
            UpdateStatus()
            return " - Error (CS Connect not found)"
        }

        try {
            btn.Click()
        } catch {
            ; Legacy UI might throw an error even though the click succeeds and opens the window
        }

        UpdateStatus("Waiting for CS Connect window to load...", 100, 100)
        WinWaitActive("CS Connect")
        try {
            UpdateStatus("Pressing Call Now button...", 100, 100)
            UIA.ElementFromHandle("CS Connect").WaitElement({ Name: "Call Now", Type: "Button" }).Click()
        } catch {
            UpdateStatus("Could not find Call Now button...", 100, 100)
            WinActivate("CS Connect")
            Sleep(500)
            Send("{Enter}")
        }

        WinWait("Call Summary")
        callSumEl := UIA.ElementFromHandle("Call Summary")

        ; Read Status
        statusText := callSumEl.WaitElement({ Type: "Document" }).Value

    } catch as err {
        MsgBox("UI Error during CS Connect: " . err.Message)
        UpdateStatus()
        return " - Error (UI)"
    }

    ; --- 3. Check Update Status -----------------------------------------------

    ; CASE A: No Updates
    if InStr(statusText, "No new updates") {
        try callSumEl.FindElement({ Name: "Close", Type: "Button" }).Highlight().Click()
        Sleep(500)
        WinClose("Accounting CS")
        UpdateStatus()
        return " - No updates"
    }

    ; CASE B: Updates Found
    else {
        try callSumEl.FindElement({ Name: "Close", Type: "Button" }).Highlight().Click()
        Sleep(500)
        
        ; Handle the 'Apply Updates' prompt that appears when closing Call Summary
        if WinWait("Apply Updates", "Would you like to apply them now?", 5) {
            try {
                UIA.ElementFromHandle("Apply Updates").WaitElement({ Name: "No", Type: "Button" }).Click()
            } catch {
                ; Fallback to keyboard
                WinActivate("Apply Updates")
                Send("!n") ; Alt+N for No, or just Tab/Right Arrow to select No
            }
            Sleep(500)
        }

        WinClose("Accounting CS")
        UpdateStatus()
        return " - Update found, install manually"

        /*
        UpdateStatus("Updates detected... applying.", 100, 100)

        ; Close Call Summary to trigger the Apply/Restart flow
        try callSumEl.FindElement({ Name: "Close", Type: "Button" }).Click()

        ; Handle Restart Prompt
        if WinWait("Accounting CS", "Updates have been applied", 5) {
            try UIA.ElementFromHandle("Accounting CS").WaitElement({ Name: "OK", Type: "Button" }).Click()
        }

        UpdateStatus("Waiting for Accounting CS to restart...", 100, 100)
        WinWaitClose("Accounting CS")

        ; Wait for App to Reload
        WinWait("Accounting CS")
        WinActivate("Accounting CS")

        TRLogin()

        ; Recursive Call: Verify the update is finished
        AccountingCS()
        UpdateStatus()
        return " - Updates installed"
        */
    }
}
