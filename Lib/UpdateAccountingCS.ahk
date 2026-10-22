#Requires AutoHotkey v2.0

GetAccountingCSPath() {
    ; 1. Authoritative desktop shortcuts (C:\Users\Public\Desktop\Applications, etc.)
    scPath := FindShortcutPath(["AccountingCS.exe", "acs.exe"], ["(?i)Accounting\s*CS|(?i)\bACS\b"])
    if (scPath != "")
        return scPath

    ; 2. Candidate network & local paths
    potentialPaths := [
        ; UNC network shares
        "\\sql1\WinCSI\Accounting CS\AccountingCS.exe",
        "\\sql1\WINCSI$\Accounting CS\AccountingCS.exe",
        "\\wbsql1\WINCSI$\Accounting CS\AccountingCS.exe",
        "\\app1\WinCSI\Accounting CS\AccountingCS.exe",
        "\\agcfsapp1\WinCSI\Accounting CS\AccountingCS.exe",
        "\\chfsapp1\WINCSI\Accounting CS\AccountingCS.exe",
        "\\tho1\thomson\WINCSI\Accounting CS\AccountingCS.exe",

        ; Mapped network drive letters & local paths
        "W:\Creative Solutions\Accounting CS\AccountingCS.exe",
        "X:\Creative Solutions\Accounting CS\AccountingCS.exe",
        "P:\Creative Solutions\Accounting CS\AccountingCS.exe",
        "S:\Creative Solutions\Accounting CS\AccountingCS.exe",
        "C:\Program Files (x86)\Creative Solutions\Accounting CS\AccountingCS.exe",
        "C:\Program Files\Creative Solutions\Accounting CS\AccountingCS.exe"
    ]

    for index, path in potentialPaths {
        if SafeFileExist(path) {
            return path
        }
    }
    return ""
}

AccountingCS(PostUpdate := false) {
    acsExe := ""
    if (!PostUpdate) {
        acsPath := GetAccountingCSPath()
        if (acsPath = "") {
            MsgBox("Error: Accounting CS executable not found in any specified location.")
            return " - Error (Path not found)"
        }
        SplitPath(acsPath, &acsExe)
        Run(acsPath)

        TRLogin() ; Initial Login
    } else {
        acsPath := GetAccountingCSPath()
        if (acsPath != "")
            SplitPath(acsPath, &acsExe)
    }

    WinWait("Accounting CS")
    WinActivate("Accounting CS")
    WinMaximize("Accounting CS")

    ; --- Database Login Automation ---
    global AcsPassword
    loginResult := SubmitCSDatabaseLogin("Accounting CS", acsExe, AcsPassword)
    if (loginResult != true) {
        UpdateStatus()
        return loginResult
    }

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
