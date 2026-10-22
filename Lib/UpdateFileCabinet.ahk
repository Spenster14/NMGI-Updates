#Requires AutoHotkey v2.0

GetFileCabinetPath() {
    ; 1. Authoritative desktop shortcuts (C:\Users\Public\Desktop\Applications, etc.)
    scPath := FindShortcutPath("fcab.exe", ["(?i)FileCabinet|(?i)File\s*Cabinet"])
    if (scPath != "")
        return scPath

    ; 2. Candidate network & local paths
    potentialPaths := [
        ; Local installations (C:\)
        "C:\WinCSI\CABINET\fcab.exe",

        ; Mapped network drive letters (alphabetical: W, X)
        "W:\WinCSI\CABINET\fcab.exe",
        "X:\CABINET\fcab.exe",

        ; UNC network shares (alphabetical: agcfsapp1, app1, chfsapp1, sql1, tho1, wbsql1)
        "\\agcfsapp1\WinCSI\CABINET\fcab.exe",
        "\\app1\WinCSI\CABINET\fcab.exe",
        "\\chfsapp1\WINCSI\CABINET\fcab.exe",
        "\\sql1\WinCSI\CABINET\fcab.exe",
        "\\sql1\WINCSI$\CABINET\fcab.exe",
        "\\tho1\Thomson\WinCSI\CABINET\fcab.exe",
        "\\wbsql1\WINCSI$\CABINET\fcab.exe"
    ]

    for index, path in potentialPaths {
        if SafeFileExist(path) {
            return path
        }
    }
    return ""
}

FileCabinet(PostUpdate := false) {
    ; --- 1. Launch / Activate -------------------------------------------------
    if (!PostUpdate) {
        fcabPath := GetFileCabinetPath()
        if (fcabPath = "") {
            MsgBox("Error: FileCabinet executable not found in any specified location.")
            return " - Error (Path not found)"
        }
        Run(fcabPath)

        TRLogin() ; Login helper
    }

    Sleep(2000)
    ; --- 2. Navigate to CS Connect --------------------------------------------
    try {
        ; Wait for the main FileCabinet window to fully load and expose the update button.
        UpdateStatus("Waiting for FileCabinet CS Main Window...", 100, 100)

        ; Splash screens typically cannot be maximized (MinMax = 1)
        ; We loop until the window successfully maximizes, proving it is the main application.
        loop 60 {
            if WinExist("FileCabinet CS") {
                try WinActivate("FileCabinet CS")
                try WinMaximize("FileCabinet CS")

                if (WinGetMinMax("FileCabinet CS") == 1) {
                    break
                }
            }
            Sleep(2000)
        }

        UpdateStatus("Waiting for CS Connect button...", 100, 100)
        btn := ""
        loop 60 { ; Try for up to 120 seconds (2s sleeps)
            ; Clear popups if they appear
            if WinExist("Choose Data Location") {
                WinActivate("Choose Data Location")
                try {
                    UIA.ElementFromHandle("Choose Data Location").FindElement({ Name: "OK", Type: "Button" }).Click()
                } catch {
                    Send("{Enter}")
                }
                Sleep(500)
            }
            if WinExist("User Bulletin") {
                try {
                    UIA.ElementFromHandle("User Bulletin").FindElement({ Name: "Close", Type: "Button" }).Click()
                } catch {
                    WinClose("User Bulletin")
                }
            }
            if WinExist("Onvio") {
                try {
                    WinClose("Onvio")
                }
            }

            try {
                if WinExist("FileCabinet CS") {
                    ; Get the main window element
                    fcEl := UIA.ElementFromHandle("FileCabinet CS")
                    ; FindElement scans the UI tree exactly once without timing out prematurely.
                    btn := fcEl.FindElement({ Name: "CS Connect (Ctrl+K)", Type: "Button" })

                    if btn {
                        ; Attempt to click it immediately. If a modal is suddenly active,
                        ; the click will throw an error, preventing the break, and allowing
                        ; the loop to clear the modal on the next iteration.
                        btn.Click()
                        break
                    }
                }
            } catch {
                ; Ignore exceptions (like unready window tree or disabled controls) and retry
            }
            Sleep(2000)
        }
        UpdateStatus()

        if !btn {
            throw Error("Timed out waiting or trying to click 'CS Connect' button after 120 seconds.")
        }

        WinWait("CS Connect")
        UIA.ElementFromHandle("CS Connect").WaitElement({ Name: "Call Now", Type: "Button" }, 10000).Click()

        WinWait("Call Summary")
        callSumEl := UIA.ElementFromHandle("Call Summary")

        ; Read the result text (usually in a ListItem or Document element)
        ; We try ListItem first as per your original code, but fall back if needed
        try {
            statusText := callSumEl.FindElement({ Type: "ListItem" }).Name
        } catch {
            statusText := "" ; Default to empty if element not found
        }

    } catch as err {
        MsgBox("UI Error during CS Connect: " . err.Message)
        return " - Error (UI)"
    }

    ; --- 3. Check Update Status -----------------------------------------------

    ; CASE A: No Updates Found
    if InStr(statusText, "No new updates") {
        try callSumEl.FindElement({ Name: "Close", Type: "Button" }).Highlight().Click()
        Sleep(500)

        ; Check if FileCabinet prompts about older pending updates
        pid := 0
        try pid := WinGetPID("FileCabinet CS")
        if WinWait("FileCabinet CS", "apply them now", 3) {
            WinActivate("FileCabinet CS")
            try UIA.ElementFromHandle("FileCabinet CS").WaitElement({ Name: "Yes", Type: "Button" }, 3000).Click()
            catch {
                Send("y")
            }

            ; Check if program is locked by other users
            if WinWait("FileCabinet CS", "while other users are accessing", 3) {
                try UIA.ElementFromHandle("FileCabinet CS").WaitElement({ Name: "Cancel", Type: "Button" }, 2000).Click()
                catch {
                    Send("{Esc}")
                }
                Sleep(500)
                WinClose("FileCabinet CS")
                WinWaitClose("FileCabinet CS")
                if (pid)
                    ProcessWaitClose(pid)
                return " - Update still pending, users in application"
            }

            UpdateStatus("Pending updates detected... applying and restarting.", 100, 100)
            WinWaitClose("FileCabinet CS")
            if (pid)
                ProcessWaitClose(pid)

            FileCabinet(true) ; Verify after restart
            return " - Updates installed"
        }
        UpdateStatus("Closing FileCabinet...", 100, 100)
        WinClose("FileCabinet CS")
        WinWaitClose("FileCabinet CS")
        if (pid)
            ProcessWaitClose(pid)
        return " - No updates"
    }

    ; CASE B: Updates Found
    else {
        UpdateStatus("Updates detected... applying.", 100, 100)

        pid := 0
        try pid := WinGetPID("FileCabinet CS")

        ; Usually we click "Close" or "Done" to trigger the install/restart process
        try callSumEl.FindElement({ Name: "Close", Type: "Button" }).Click()

        ; Wait for "Restart" prompt
        ; Note: FileCabinet sometimes just closes without a prompt if the update is minor,
        ; but if there is a dialog, we handle it here.
        if WinWait("FileCabinet CS", "Restart", 5) {
            try UIA.ElementFromHandle("FileCabinet CS").WaitElement({ Name: "OK", Type: "Button" }).Click()
            catch {
                Send("{Enter}")
            }
        }

        ; Check if program is locked by other users
        if WinWait("FileCabinet CS", "while other users are accessing", 3) {
            try UIA.ElementFromHandle("FileCabinet CS").WaitElement({ Name: "Cancel", Type: "Button" }, 2000).Click()
            catch {
                Send("{Esc}")
            }
            Sleep(500)
            WinClose("FileCabinet CS")
            WinWaitClose("FileCabinet CS")
            if (pid)
                ProcessWaitClose(pid)
            return " - Update still pending, users in application"
        }

        UpdateStatus("Waiting for FileCabinet to restart...", 100, 100)

        ; Wait for it to close completely
        WinWaitClose("FileCabinet CS")
        if (pid)
            ProcessWaitClose(pid)

        ; Relaunch to verify (Recursive call)
        ; We pass 'true' for PostUpdate so it skips the login and just checks bulletins
        FileCabinet(true)

        return " - Updates installed"
    }
}

