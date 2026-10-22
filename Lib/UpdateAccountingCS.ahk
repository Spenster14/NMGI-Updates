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
            return " - Error (Path not found)"
        }
        Run(acsPath)

        TRLogin() ; Initial Login
    }

    ;UpdateStatus("Waiting for Accounting CS to load...", 100, 100)
    WinWait("Accounting CS")
    WinActivate("Accounting CS")
    WinMaximize("Accounting CS")
    UpdateStatus("Waiting for Accounting CS to load...", 100, 100)

    ; --- Database Login Automation ---
    global AcsPassword
    if (AcsPassword != "") {
        UpdateStatus("Submitting Accounting CS database password...", 100, 100)
        handledLogin := false
        loop 40 {
            if WinExist("Accounting CS -") {
                handledLogin := true
                break
            }

            if WinExist("Accounting CS") {
                WinActivate("Accounting CS")

                ; Tier A: UIA inspection for Password Edit element
                try {
                    aEl := UIA.ElementFromHandle("Accounting CS")
                    pwdEl := ""
                    try pwdEl := aEl.FindElement({Type: "Edit", IsPassword: true})
                    if (!pwdEl) {
                        try pwdEl := aEl.FindElement({Name: "Password", Type: "Edit", mm: 2})
                    }
                    if (!pwdEl) {
                        try pwdEl := aEl.FindElement({AutomationId: "txtPassword", mm: 2})
                    }

                    if (pwdEl) {
                        try pwdEl.Highlight(500)
                        pwdEl.Click("left")
                        Sleep(100)
                        SendText(AcsPassword)
                        Sleep(200)

                        okBtn := ""
                        try okBtn := aEl.FindElement({Name: "OK", Type: "Button", mm: 2})
                        if (okBtn)
                            okBtn.Click()
                        else
                            Send("{Enter}")

                        handledLogin := true
                        break
                    }
                }

                ; Tier B: Win32 Edit control with ES_PASSWORD (0x0020)
                try {
                    controls := WinGetControls("Accounting CS")
                    ctrlHwnds := WinGetControlsHwnd("Accounting CS")
                    for i, ctrlName in controls {
                        if InStr(ctrlName, "Edit") {
                            style := WinGetStyle(ctrlHwnds[i])
                            if (style & 0x0020) {
                                ControlFocus(ctrlHwnds[i], "Accounting CS")
                                ControlSetText(AcsPassword, ctrlHwnds[i], "Accounting CS")
                                Sleep(200)
                                ControlClick("&OK", "Accounting CS")
                                handledLogin := true
                                break
                            }
                        }
                    }
                    if (handledLogin)
                        break
                }
            }
            Sleep(500)
        }

        ; Fallback: Tab navigation if still on login screen
        if (!handledLogin && WinExist("Accounting CS") && !WinExist("Accounting CS -")) {
            WinActivate("Accounting CS")
            Send("{Tab 2}")
            Sleep(200)
            SendText(AcsPassword)
            Sleep(200)
            Send("{Enter}")
        }
    }

    UpdateStatus("Waiting for Accounting CS dashboard to load...", 100, 100)

    ; Wait for the main dashboard to appear (which means login is complete)
    WinWait("Accounting CS -", , 120)
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

        ; Invoke blocks while the modal CS Connect dialog is open - bound it so Jacro never freezes.
        UpdateStatus("Opening Accounting CS Connect...", 100, 100)
        InvokeNoFreeze(btn)

        UpdateStatus("Waiting for CS Connect window to load...", 100, 100)
        csExe := ""
        try csExe := WinGetProcessName("Accounting CS -")
        hCS := WaitForCSConnect(csExe, 20000)
        if (!hCS) {
            UpdateStatus()
            return " - Error (CS Connect window not found)"
        }
        UpdateStatus("CS Connect found. Pressing Call Now...", 100, 100)
        ClickCallNow(hCS)

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
        return " - Updates available (Manual)"
    }
}
