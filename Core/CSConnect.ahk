#Requires AutoHotkey v2.0
; Core/CSConnect.ahk - Shared, non-freezing "CS Connect" launcher for Practice CS and Accounting CS.
;
; WHY THIS EXISTS
;   UIA btn.Click() calls InvokePattern.Invoke(), a synchronous cross-process call. The CS Connect
;   toolbar button opens a MODAL dialog, so the target app does not answer the call until that dialog
;   closes. Jacro has a single thread, so it froze (busy cursor, status stuck) until UIA's
;   TransactionTimeout (20s default, hit twice => ~40s) expired - long after the dialog was on screen.
;   Fix: bound that one call with a short timeout, then drive the dialog with plain Win32 messages
;   (no UIA, no modal COM waits) using yielding polls so the GUI message loop keeps running.

; Invokes the toolbar button but returns after boundMs instead of ~40s while the modal dialog is open.
; The Invoke is still delivered to the app; only Jacro's wait for the reply is cut short.
InvokeNoFreeze(btn, boundMs := 1500) {
    prev := ""
    try prev := UIA.TransactionTimeout
    try UIA.TransactionTimeout := boundMs
    try btn.Click()
    if (prev != "")
        try UIA.TransactionTimeout := prev
}

; Finds the CS Connect dialog owned by exeName. Visible windows first, hidden as a fallback.
; TitleMatchMode / DetectHiddenWindows are per-thread, so they are restored before returning.
FindCSConnectHwnd(exeName := "") {
    spec := "CS Connect" . (exeName != "" ? " ahk_exe " . exeName : "")
    prevTM := A_TitleMatchMode
    prevDHW := A_DetectHiddenWindows
    SetTitleMatchMode(2)
    hwnd := WinExist(spec)
    if (!hwnd) {
        DetectHiddenWindows(true)
        hwnd := WinExist(spec)
    }
    DetectHiddenWindows(prevDHW)
    SetTitleMatchMode(prevTM)
    return hwnd
}

; Yielding poll (Sleep pumps messages, so Jacro's GUI stays responsive). Returns HWND or 0.
WaitForCSConnect(exeName := "", timeoutMs := 20000) {
    t0 := A_TickCount
    while (A_TickCount - t0 < timeoutMs) {
        if (hwnd := FindCSConnectHwnd(exeName))
            return hwnd
        Sleep(100)
    }
    return 0
}

; Yielding wait until the dialog is gone. Returns true if it closed.
CSConnectClosed(hwnd, timeoutMs := 1500) {
    t0 := A_TickCount
    while (A_TickCount - t0 < timeoutMs) {
        if (!WinExist("ahk_id " . hwnd))
            return true
        Sleep(50)
    }
    return !WinExist("ahk_id " . hwnd)
}

; Presses "Call Now" with a multi-tier fallback. Returns the tier that worked, or "" if none did.
ClickCallNow(hwnd) {
    win := "ahk_id " . hwnd

    ; Tier A: exact-text control match (NOT a substring: the "Connect now" radio also contains "now").
    try {
        nns := WinGetControls(win)
        hws := WinGetControlsHwnd(win)
        for i, nn in nns {
            txt := ""
            try txt := ControlGetText(hws[i])
            if RegExMatch(StrReplace(txt, "&"), "i)^\s*call\s*now\s*$") {
                try ControlClick(hws[i], win, , , , "NA")
                if CSConnectClosed(hwnd, 1500)
                    return "A:ControlClick"
                try PostMessage(0x00F5, 0, 0, hws[i], win)   ; BM_CLICK (posted, never blocks)
                if CSConnectClosed(hwnd, 1500)
                    return "A:BM_CLICK"
                break
            }
        }
    }

    ; Tier B: keyboard. "Call Now" is the dialog's default button (Enter); !o / !n are accelerators.
    try {
        WinActivate(win)
        if WinWaitActive(win, , 1.5) {
            Send("{Enter}")
            if CSConnectClosed(hwnd, 1500)
                return "B:Enter"
            Send("!o")
            if CSConnectClosed(hwnd, 1500)
                return "B:Alt+O"
            Send("!n")
            if CSConnectClosed(hwnd, 1500)
                return "B:Alt+N"
        }
    }

    ; Tier C: click at the button's relative position in the dialog's client area.
    try {
        WinGetClientPos(, , &cw, &ch, win)
        cx := Round(cw * 0.745), cy := Round(ch * 0.92)
        ControlClick("x" . cx . " y" . cy, win, , , , "NA")
        if CSConnectClosed(hwnd, 1500)
            return "C:RelativeClick"
    }
    return ""
}

; Submits database password for CS Professional Suite apps (Practice CS and Accounting CS).
; Identifies the active login modal dialog and precisely targets the Password textbox.
; Explicitly excludes ComboBox child edit controls (Open Firm, Staff ID) to prevent field corruption.
SubmitCSDatabaseLogin(winPrefix, exeName, dbPassword) {
    if (dbPassword != "") {
        UpdateStatus("Submitting " . winPrefix . " database password...", 100, 100)
    } else {
        UpdateStatus("Waiting for " . winPrefix . " to load...", 100, 100)
    }

    ; If dashboard already loaded, no password entry required
    if WinExist(winPrefix . " -") {
        WinActivate(winPrefix . " -")
        WinMaximize(winPrefix . " -")
        return true
    }

    handledLogin := false

    if (dbPassword != "") {
        ; Poll up to 30 seconds (60 x 500ms) for the login modal dialog
        loop 60 {
            if WinExist(winPrefix . " -") {
                handledLogin := true
                break
            }

            hwnds := []
            if (exeName != "") {
                try hwnds := WinGetList("ahk_exe " . exeName)
            }
            if (hwnds.Length == 0) {
                try hwnds := WinGetList(winPrefix)
            }

            loginHwnd := 0
            for h in hwnds {
                style := 0
                try style := WinGetStyle(h)
                if (!(style & 0x10000000)) ; Must be visible (WS_VISIBLE)
                    continue

                title := ""
                try title := WinGetTitle(h)
                if InStr(title, winPrefix . " -")
                    continue

                ctrls := []
                try ctrls := WinGetControls(h)
                hasEdit := false
                hasButtons := false
                for c in ctrls {
                    if InStr(c, "Edit")
                        hasEdit := true
                    if InStr(c, "Button") {
                        txt := ""
                        try txt := ControlGetText(c, h)
                        if (txt = "OK" || InStr(txt, "OK") || InStr(txt, "Cancel") || InStr(txt, "Change password"))
                            hasButtons := true
                    }
                }
                if (hasEdit && hasButtons) {
                    loginHwnd := h
                    break
                }
            }

            if (loginHwnd) {
                WinActivate("ahk_id " . loginHwnd)
                Sleep(100)

                ctrlNames := []
                ctrlHwnds := []
                try ctrlNames := WinGetControls("ahk_id " . loginHwnd)
                try ctrlHwnds := WinGetControlsHwnd("ahk_id " . loginHwnd)

                standaloneEdits := []
                comboHwnds := []
                okCtrlHwnd := 0
                pwdLabelHwnd := 0

                for i, c in ctrlNames {
                    h := ctrlHwnds[i]
                    if InStr(c, "Button") {
                        txt := ""
                        try txt := ControlGetText(h, "ahk_id " . loginHwnd)
                        if (txt = "OK" || InStr(txt, "OK"))
                            okCtrlHwnd := h
                    } else if InStr(c, "ComboBox") {
                        comboHwnds.Push(h)
                    } else if InStr(c, "STATIC") || InStr(c, "Text") {
                        txt := ""
                        try txt := ControlGetText(h, "ahk_id " . loginHwnd)
                        ; Must match "Password:" label and NOT "Change password..." button/label
                        if (txt = "Password:" || (InStr(txt, "Password:") && !InStr(txt, "Change")))
                            pwdLabelHwnd := h
                    } else if InStr(c, "Edit") {
                        ; CRITICAL RULE: Filter out any Edit control that is inside a ComboBox (e.g. Open Firm)
                        parent := DllCall("GetParent", "ptr", h, "ptr")
                        pClass := ""
                        if (parent) {
                            try pClass := WinGetClass(parent)
                        }
                        if (!InStr(pClass, "COMBOBOX") && !InStr(pClass, "ComboBox")) {
                            standaloneEdits.Push(h)
                        }
                    }
                }

                ; Auto-recovery: If the Password: label is missing, Open Firm was likely corrupted.
                ; Check if any ComboBox contains dbPassword, and restore the first firm in the list.
                if (!pwdLabelHwnd) {
                    for cb in comboHwnds {
                        cbText := ""
                        try cbText := ControlGetText(cb, "ahk_id " . loginHwnd)
                        if (cbText = dbPassword || InStr(cbText, dbPassword)) {
                            ; Reset to the first valid firm in the dropdown
                            SendMessage(0x014E, 0, 0, cb, "ahk_id " . loginHwnd) ; CB_SETCURSEL 0
                            cbId := DllCall("GetDlgCtrlID", "ptr", cb, "int")
                            SendMessage(0x0111, (1 << 16) | (cbId & 0xFFFF), cb, "ahk_id " . loginHwnd) ; CBN_SELCHANGE
                            ControlFocus(cb, "ahk_id " . loginHwnd)
                            Send("{Down}{Enter}")
                            Sleep(500)
                            break
                        }
                    }
                    UpdateStatus("Waiting for " . winPrefix . " Password field...", 100, 100)
                    Sleep(500)
                    continue
                }

                ; Locate the exact password control on the dialog
                pwdCtrl := 0
                lx := 0, ly := 0, lw := 0, lh := 0
                ControlGetPos(&lx, &ly, &lw, &lh, pwdLabelHwnd, "ahk_id " . loginHwnd)

                ; 1. First, search standalone edits that are on the same row as Password:
                for eh in standaloneEdits {
                    ex := 0, ey := 0, ew := 0, ehH := 0
                    ControlGetPos(&ex, &ey, &ew, &ehH, eh, "ahk_id " . loginHwnd)
                    ; On the same vertical line (within 20px) and horizontally to the right of "Password:"
                    if (Abs(ey - ly) <= 20 && ex >= lx + lw - 10) {
                        pwdCtrl := eh
                        break
                    }
                }

                ; 2. Fallback: Check if any standalone edit has ES_PASSWORD (0x0020)
                if (!pwdCtrl) {
                    for eh in standaloneEdits {
                        s := 0
                        try s := WinGetStyle(eh)
                        if (s & 0x0020) {
                            pwdCtrl := eh
                            break
                        }
                    }
                }

                ; Inject password into the verified password control
                if (pwdCtrl) {
                    try ControlFocus(pwdCtrl, "ahk_id " . loginHwnd)
                    Sleep(150)
                    try ControlClick(pwdCtrl, "ahk_id " . loginHwnd, , , , "NA")
                    Sleep(150)
                    Send("^a{Backspace}")
                    Sleep(100)
                    SendText(dbPassword)
                    Sleep(200)
                } else if (pwdLabelHwnd) {
                    clickX := lx + lw + 40
                    clickY := ly + (lh // 2)
                    ControlClick("x" . clickX . " y" . clickY, "ahk_id " . loginHwnd, , , , "NA")
                    Sleep(150)
                    Send("^a{Backspace}")
                    Sleep(100)
                    SendText(dbPassword)
                    Sleep(200)
                }

                ; SINGLE deliberate submit action - never spam multiple click events
                UpdateStatus("Submitting " . winPrefix . " credentials...", 100, 100)
                if (okCtrlHwnd) {
                    try ControlClick(okCtrlHwnd, "ahk_id " . loginHwnd, , , , "NA")
                } else {
                    Send("{Enter}")
                }

                ; Exit the input loop immediately so we never re-enter or re-submit
                handledLogin := true
                break
            }
            Sleep(500)
        }
    }

    ; Patient verification loop: wait for SQL database verification over network without re-submitting
    UpdateStatus("Waiting for " . winPrefix . " database verification...", 100, 100)
    tWait := A_TickCount
    dashboardLoaded := false
    while (A_TickCount - tWait < 45000) {
        ; 1. Check if dashboard appeared
        if WinExist(winPrefix . " -") {
            dashboardLoaded := true
            break
        }

        ; 2. Check if error dialog appeared (and dismiss all stacked popups if multiple exist)
        if DismissAllLoginErrors(winPrefix, exeName, loginHwnd) {
            ; Dismiss the underlying login card
            if (loginHwnd && WinExist("ahk_id " . loginHwnd)) {
                try ControlClick("Cancel", "ahk_id " . loginHwnd, , , , "NA")
                Send("{Esc}")
                Sleep(200)
            } else if (WinExist(winPrefix)) {
                try ControlClick("Cancel", winPrefix, , , , "NA")
                Send("{Esc}")
            }
            UpdateStatus(winPrefix . ": Invalid database credentials.")
            return " - Error (Invalid credentials)"
        }

        Sleep(250)
    }

    if (!dashboardLoaded) {
        UpdateStatus(winPrefix . ": Dashboard load timeout.")
        return " - Error (Login timeout)"
    }

    WinActivate(winPrefix . " -")
    WinMaximize(winPrefix . " -")
    return true
}

; Detects and dismisses Thomson Reuters invalid credential error dialogs.
; Recursively clears any stacked error modals and returns true if any were handled.
DismissAllLoginErrors(winPrefix, exeName, loginHwnd := 0) {
    foundAny := false

    loop 5 {
        foundThisIter := false
        hwnds := []
        if (exeName != "") {
            try {
                for h in WinGetList("ahk_exe " . exeName)
                    hwnds.Push(h)
            }
        }
        try {
            for h in WinGetList(winPrefix) {
                already := false
                for existing in hwnds {
                    if (existing == h) {
                        already := true
                        break
                    }
                }
                if (!already)
                    hwnds.Push(h)
            }
        }

        for h in hwnds {
            if (loginHwnd && h == loginHwnd)
                continue

            ; 1. Check parent window text
            wText := ""
            try wText := WinGetText("ahk_id " . h)

            ; 2. Inspect child controls for text (critical for WinForms STATIC labels)
            cList := []
            cHwnds := []
            try cList := WinGetControls("ahk_id " . h)
            try cHwnds := WinGetControlsHwnd("ahk_id " . h)
            for idx, cName in cList {
                cTxt := ""
                try cTxt := ControlGetText(cHwnds[idx], "ahk_id " . h)
                if (cTxt != "")
                    wText .= " " . cTxt
            }

            ; 3. UIA fallback on small dialog
            if (!InStr(wText, "not valid for the Firm")) {
                try {
                    oldTo := UIA.TransactionTimeout
                    UIA.TransactionTimeout := 500
                    hEl := UIA.ElementFromHandle(h)
                    wText .= " " . hEl.DumpAll()
                    UIA.TransactionTimeout := oldTo
                }
            }

            if (InStr(wText, "not valid for the Firm") || InStr(wText, "valid Staff ID and Password") || (InStr(wText, "Staff ID") && InStr(wText, "Password") && InStr(wText, "not valid"))) {
                foundAny := true
                foundThisIter := true

                ; Find and click the OK button on the error popup
                okClicked := false
                for idx, cName in cList {
                    if InStr(cName, "Button") {
                        bTxt := ""
                        try bTxt := ControlGetText(cHwnds[idx], "ahk_id " . h)
                        if (bTxt = "OK" || InStr(bTxt, "OK")) {
                            ControlClick(cHwnds[idx], "ahk_id " . h, , , , "NA")
                            okClicked := true
                            break
                        }
                    }
                }
                if (!okClicked) {
                    try ControlClick("OK", "ahk_id " . h, , , , "NA")
                    try PostMessage(0x0111, 1, 0, , "ahk_id " . h) ; IDOK
                    Send("{Enter}")
                }
                try WinClose("ahk_id " . h)
                Sleep(250)
                break ; restart search to catch any underlying stacked popups
            }
        }

        if (!foundThisIter)
            break
    }

    return foundAny
}
