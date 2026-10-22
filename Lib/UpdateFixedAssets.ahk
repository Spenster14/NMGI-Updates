#Requires AutoHotkey v2.0

GetFixedAssetsPath() {
    ; 1. Authoritative desktop shortcuts (C:\Users\Public\Desktop\Applications, etc.)
    scPath := FindShortcutPath("dsw.exe", ["(?i)Fixed\s*Assets|(?i)\bDSW\b"])
    if (scPath != "")
        return scPath

    ; 2. Candidate network & local paths
    potentialPaths := [
        ; UNC network shares
        "\\goserver\Y\WinCSI\DSW\dsw.exe",
        "\\goserver\Y$\WinCSI\DSW\dsw.exe",
        "\\goserver\WinCSI\DSW\dsw.exe",
        "\\goserver\WINCSI$\DSW\dsw.exe",
        "\\agcfsapp1\WinCSI\DSW\dsw.exe",
        "\\wbsql1\WINCSI$\DSW\dsw.exe",
        "\\chfsapp1\WINCSI\DSW\dsw.exe",
        "\\hfaapp1\WINCSI\FA25\DSW\dsw.exe",
        "\\app1\WinCSI\DSW\dsw.exe",

        ; Mapped network drive letters & local paths
        "Y:\WinCSI\DSW\dsw.exe",
        "Y:\DSW\dsw.exe",
        "X:\DSW\DSW.exe",
        "U:\WinCSI\DSW\dsw.exe",
        "W:\WinCSI\DSW\dsw.exe",
        "C:\WinCSI\DSW\dsw.exe"
    ]

    for index, path in potentialPaths {
        if SafeFileExist(path) {
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
            return " - Error (Path not found)"
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

