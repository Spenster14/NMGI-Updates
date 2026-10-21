#Requires AutoHotkey v2.0
; Lib/UpdatePractice.ahk - Thomson Reuters Practice CS orchestration module.
; Checks for updates via CS Connect and defers installation (manual flag)
; to prevent disruptive firm-wide database locks.

GetPracticePath() {
    potentialPaths := [
        "W:\Creative Solutions\Practice CS\PracticeCS.exe",
        "X:\Creative Solutions\Practice CS\PracticeCS.exe",
        "P:\Creative Solutions\Practice CS\PracticeCS.exe",
        "S:\Creative Solutions\Practice CS\PracticeCS.exe",
        "\\wbsql1\WINCSI$\Practice CS\PracticeCS.exe",
        "\\tho1\thomson\WINCSI\Practice CS\PracticeCS.exe",
        "\\agcfsapp1\WinCSI\Practice CS\PracticeCS.exe",
        "C:\Program Files (x86)\Creative Solutions\Practice CS\PracticeCS.exe",
        "C:\Program Files\Creative Solutions\Practice CS\PracticeCS.exe",
        "C:\WinCSI\Practice CS\PracticeCS.exe",
        "W:\Creative Solutions\Practice CS\practice.exe",
        "X:\Creative Solutions\Practice CS\practice.exe",
        "C:\Program Files (x86)\Creative Solutions\Practice CS\practice.exe",
        "C:\Program Files\Creative Solutions\Practice CS\practice.exe"
    ]

    for path in potentialPaths {
        if SafeFileExist(path) {
            return path
        }
    }
    return ""
}

Practice(PostUpdate := false) {
    ; --- 1. Launch / Activate -------------------------------------------------
    if (!PostUpdate) {
        practicePath := GetPracticePath()
        if (practicePath == "") {
            MsgBox("Error: Practice CS executable not found in any specified location.")
            return " - Error (Path not found)"
        }
        Run(practicePath)

        TRLogin() ; Initial Thomson Reuters Staff Login
    }

    WinWait("Practice CS")
    WinActivate("Practice CS")
    WinMaximize("Practice CS")
    UpdateStatus("Waiting for Practice CS to load...", 100, 100)

    UpdateStatus("Waiting for user to enter password and Practice CS dashboard to load...", 100, 100)

    ; Wait for the main dashboard to appear (which indicates database login is complete)
    WinWait("Practice CS -")
    WinActivate("Practice CS -")
    WinMaximize("Practice CS -")

    UpdateStatus()

    ; Clean up startup popups (Onvio / User Bulletin)
    HandleBulletins()

    ; --- 2. Navigate to CS Connect --------------------------------------------
    WinWaitActive("Practice CS -")
    try {
        practiceEl := UIA.ElementFromHandle("Practice CS -")

        UpdateStatus("Waiting for Practice CS Connect button...", 100, 100)
        btn := ""
        loop 30 {
            try {
                if WinExist("Practice CS -") {
                    practiceEl := UIA.ElementFromHandle("Practice CS -")
                    btn := practiceEl.FindElement({ Name: "CS Connect", MatchMode: "Substring" })
                    if btn {
                        break
                    }
                }
            }
            Sleep(1000)
        }

        if !btn {
            UpdateStatus()
            return " - Error (CS Connect not found)"
        }

        try {
            btn.Click()
        } catch {
            ; ControlClick fallback if standard invoke throws
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
        UpdateStatus()
        return " - Error (UI: " . err.Message . ")"
    }

    ; --- 3. Evaluate Update Status & Defer Installation -----------------------

    ; CASE A: No Updates
    if InStr(statusText, "No new updates") {
        try callSumEl.FindElement({ Name: "Close", Type: "Button" }).Highlight().Click()
        Sleep(500)
        WinClose("Practice CS")
        UpdateStatus()
        return " - No updates"
    }
    ; CASE B: Updates Found (Defer and mark manual, matching Accounting CS policy)
    else {
        try callSumEl.FindElement({ Name: "Close", Type: "Button" }).Highlight().Click()
        Sleep(500)

        ; Handle the 'Apply Updates' prompt that appears when closing Call Summary
        if WinWait("Apply Updates", "Would you like to apply them now?", 5) {
            try {
                UIA.ElementFromHandle("Apply Updates").WaitElement({ Name: "No", Type: "Button" }).Click()
            } catch {
                WinActivate("Apply Updates")
                Send("!n")
            }
            Sleep(500)
        }

        WinClose("Practice CS")
        UpdateStatus()
        return " - Updates available (Manual)"
    }
}
