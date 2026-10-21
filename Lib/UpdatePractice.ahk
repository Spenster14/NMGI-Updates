#Requires AutoHotkey v2.0
; Lib/UpdatePractice.ahk - Thomson Reuters Practice CS orchestration module.
; Checks for updates via CS Connect and defers installation (manual flag)
; to prevent disruptive firm-wide database locks.

GetPracticePath() {
    potentialPaths := [
        ; Known confirmed production paths
        "\\sql1\winCSI\Practice CS\CreativeSolutions.Practice.exe",
        "T:\Practice CS\CreativeSolutions.Practice.exe",
        "T:\Creative Solutions\Practice CS\CreativeSolutions.Practice.exe",
        "\\sql1\WINCSI$\Practice CS\CreativeSolutions.Practice.exe",
        "\\sql1\Practice CS\CreativeSolutions.Practice.exe",
        "\\sql1\Creative Solutions\Practice CS\CreativeSolutions.Practice.exe",

        ; Standard network drive mappings (CreativeSolutions.Practice.exe)
        "W:\Practice CS\CreativeSolutions.Practice.exe",
        "W:\Creative Solutions\Practice CS\CreativeSolutions.Practice.exe",
        "X:\Practice CS\CreativeSolutions.Practice.exe",
        "X:\Creative Solutions\Practice CS\CreativeSolutions.Practice.exe",
        "P:\Practice CS\CreativeSolutions.Practice.exe",
        "P:\Creative Solutions\Practice CS\CreativeSolutions.Practice.exe",
        "S:\Practice CS\CreativeSolutions.Practice.exe",
        "S:\Creative Solutions\Practice CS\CreativeSolutions.Practice.exe",

        ; UNC network shares (CreativeSolutions.Practice.exe)
        "\\wbsql1\WINCSI$\Practice CS\CreativeSolutions.Practice.exe",
        "\\tho1\thomson\WINCSI\Practice CS\CreativeSolutions.Practice.exe",
        "\\agcfsapp1\WinCSI\Practice CS\CreativeSolutions.Practice.exe",

        ; Local installations (CreativeSolutions.Practice.exe)
        "C:\WinCSI\Practice CS\CreativeSolutions.Practice.exe",
        "C:\Practice CS\CreativeSolutions.Practice.exe",
        "C:\Program Files (x86)\Creative Solutions\Practice CS\CreativeSolutions.Practice.exe",
        "C:\Program Files\Creative Solutions\Practice CS\CreativeSolutions.Practice.exe",

        ; Legacy binary fallbacks (PracticeCS.exe / practice.exe)
        "\\sql1\winCSI\Practice CS\PracticeCS.exe",
        "T:\Practice CS\PracticeCS.exe",
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
        "\\sql1\WinCSI\Practice CS\practice.exe",
        "\\sql1\WINCSI$\Practice CS\practice.exe",
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

        ; Invoke blocks while the modal CS Connect dialog is open - bound it so Jacro never freezes.
        UpdateStatus("Opening Practice CS Connect...", 100, 100)
        InvokeNoFreeze(btn)

        ; --- Trigger CS Connect Call ---
        UpdateStatus("Waiting for CS Connect window to load...", 100, 100)
        csExe := ""
        try csExe := WinGetProcessName("Practice CS -")
        hCS := WaitForCSConnect(csExe, 20000)
        if (!hCS) {
            CSConnectLog("Practice: CS Connect window NOT found (exe=" . csExe . ")")
            UpdateStatus()
            return " - Error (CS Connect window not found)"
        }
        CSConnectLog("Practice: CS Connect hwnd=" . hCS . " exe=" . csExe . " controls: " . DescribeControls(hCS))
        UpdateStatus("CS Connect found (hwnd " . hCS . "). Pressing Call Now...", 100, 100)
        callMethod := ClickCallNow(hCS)
        CSConnectLog("Practice: Call Now result = " . (callMethod != "" ? callMethod : "NO TIER WORKED"))

        ; --- 3. Wait for Call Summary ---
        UpdateStatus("Waiting for Call Summary to appear...", 100, 100)
        if !WinWait("Call Summary", , 300) {
            UpdateStatus()
            return " - Error (Call Summary Timeout)"
        }

        ; Ensure the Call Summary window and its contents are fully initialized
        Sleep(1500)
        summaryDump := ""

        try {
            callSumEl := UIA.ElementFromHandle("Call Summary")
            ; DumpAll traverses the entire Call Summary tree and dumps all names, values, and types
            try summaryDump := callSumEl.DumpAll()
        } catch {
            summaryDump := ""
        }

        ; Fallback to native WinGetText
        winText := ""
        try winText := WinGetText("Call Summary")

        combinedText := summaryDump . "`n" . winText

    } catch as err {
        UpdateStatus()
        return " - Error (UI: " . err.Message . ")"
    }

    ; --- 4. Evaluate Update Status & Multi-Tiered Dialog Dismissal ------------
    isNoUpdates := InStr(combinedText, "No new updates") || InStr(combinedText, "No updates")

    ; Dismiss Call Summary (Multi-tier: UIA -> ControlClick -> Keyboard Enter/Space -> WinClose)
    if WinExist("Call Summary") {
        UpdateStatus("Acknowledging Call Summary Close...", 100, 100)
        closed := false
        try {
            callSumEl := UIA.ElementFromHandle("Call Summary")
            closeBtn := callSumEl.FindElement({ Name: "Close", MatchMode: "Substring", Type: "Button" })
            if closeBtn {
                try closeBtn.Highlight()
                closeBtn.Click()
                closed := true
            }
        } catch {
            closed := false
        }

        if (!closed || WinExist("Call Summary")) {
            try ControlClick("Button1", "Call Summary")
            Sleep(300)
        }
        if WinExist("Call Summary") {
            WinActivate("Call Summary")
            Sleep(200)
            Send("{Enter}")
            Sleep(300)
        }
        if WinExist("Call Summary") {
            Send("{Space}")
            Sleep(300)
        }
        if WinExist("Call Summary") {
            WinClose("Call Summary")
        }
        WinWaitClose("Call Summary", , 5)
    }

    ; Dismiss underlying "Online Status" window if present
    if WinExist("Online Status") {
        UpdateStatus("Closing Online Status dialog...", 100, 100)
        closed := false
        try {
            osEl := UIA.ElementFromHandle("Online Status")
            osBtn := osEl.FindElement({ Name: "Close", MatchMode: "Substring", Type: "Button" })
            if osBtn {
                osBtn.Click()
                closed := true
            }
        } catch {
            closed := false
        }

        if (!closed || WinExist("Online Status")) {
            try ControlClick("Button1", "Online Status")
            Sleep(300)
        }
        if WinExist("Online Status") {
            WinActivate("Online Status")
            Sleep(200)
            Send("{Enter}")
            Sleep(300)
        }
        if WinExist("Online Status") {
            WinClose("Online Status")
        }
        WinWaitClose("Online Status", , 5)
    }

    ; Close lingering CS Connect window if left open
    if WinExist("CS Connect") {
        try WinClose("CS Connect")
        WinWaitClose("CS Connect", , 3)
    }

    ; --- 5. Inspect Apply Updates Dialog & Finalize Status ---------------------
    applyUpdatesFound := false
    if (!isNoUpdates) {
        ; Thomson Reuters displays 'Apply Updates' modal only when updates are actually downloaded
        if WinWait("Apply Updates", , 4) {
            applyUpdatesFound := true
            UpdateStatus("Declining Apply Updates prompt...", 100, 100)
            try {
                UIA.ElementFromHandle("Apply Updates").WaitElement({ Name: "No", Type: "Button" }, 3000).Click()
            } catch {
                WinActivate("Apply Updates")
                Send("!n")
            }
            Sleep(500)
        }
    } else {
        if WinExist("Apply Updates") {
            applyUpdatesFound := true
            try UIA.ElementFromHandle("Apply Updates").WaitElement({ Name: "No", Type: "Button" }, 1500).Click()
            catch {
                WinActivate("Apply Updates")
                Send("!n")
            }
            Sleep(500)
        }
    }

    ; Clean up main Practice CS window
    if WinExist("Practice CS -")
        WinClose("Practice CS -")
    else if WinExist("Practice CS")
        WinClose("Practice CS")
    UpdateStatus()

    if (applyUpdatesFound) {
        return " - Updates available (Manual)"
    } else {
        return " - No updates"
    }
}
