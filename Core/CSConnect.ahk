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
                submittedNow := false
                if (pwdCtrl) {
                    try ControlFocus(pwdCtrl, "ahk_id " . loginHwnd)
                    Sleep(100)
                    try ControlClick(pwdCtrl, "ahk_id " . loginHwnd, , , , "NA")
                    Sleep(100)
                    Send("^a")
                    Sleep(50)
                    SendText(dbPassword)
                    Sleep(100)
                    try ControlSetText(dbPassword, pwdCtrl, "ahk_id " . loginHwnd)
                    Sleep(150)

                    if (okCtrlHwnd) {
                        try ControlClick(okCtrlHwnd, "ahk_id " . loginHwnd, , , , "NA")
                        try PostMessage(0x00F5, 0, 0, okCtrlHwnd, "ahk_id " . loginHwnd)
                    }
                    Send("{Enter}")
                    submittedNow := true
                } else if (pwdLabelHwnd) {
                    ; Geometric fallback: click directly to the right of the "Password:" label
                    clickX := lx + lw + 40
                    clickY := ly + (lh // 2)
                    ControlClick("x" . clickX . " y" . clickY, "ahk_id " . loginHwnd, , , , "NA")
                    Sleep(100)
                    Send("^a")
                    Sleep(50)
                    SendText(dbPassword)
                    Sleep(150)
                    if (okCtrlHwnd) {
                        try ControlClick(okCtrlHwnd, "ahk_id " . loginHwnd, , , , "NA")
                    }
                    Send("{Enter}")
                    submittedNow := true
                }

                if (submittedNow) {
                    ; Poll up to 4s: check if error dialog appeared, dialog closed, or dashboard appeared
                    tSub := A_TickCount
                    while (A_TickCount - tSub < 4000) {
                        if WinExist(winPrefix . " -") {
                            handledLogin := true
                            break
                        }
                        if CheckCSLoginError(winPrefix, exeName, loginHwnd) {
                            return " - Error (Invalid credentials)"
                        }
                        if (!WinExist("ahk_id " . loginHwnd)) {
                            handledLogin := true
                            break
                        }
                        Sleep(150)
                    }
                    if (handledLogin)
                        break
                }
            }
            Sleep(500)
        }
    }

    UpdateStatus("Waiting for " . winPrefix . " dashboard to load...", 100, 100)
    tWait := A_TickCount
    dashboardLoaded := false
    while (A_TickCount - tWait < 60000) {
        if WinExist(winPrefix . " -") {
            dashboardLoaded := true
            break
        }
        if CheckCSLoginError(winPrefix, exeName, loginHwnd) {
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

; Detects and dismisses the Thomson Reuters invalid credential error dialog.
; Returns true if the error dialog was found and dismissed; false otherwise.
CheckCSLoginError(winPrefix, exeName, loginHwnd := 0) {
    hwnds := []
    if (exeName != "") {
        try hwnds := WinGetList("ahk_exe " . exeName)
    }
    if (hwnds.Length == 0) {
        try hwnds := WinGetList(winPrefix)
    }

    for h in hwnds {
        if (loginHwnd && h == loginHwnd)
            continue

        ; Check text of the window
        txt := ""
        try txt := WinGetText("ahk_id " . h)
        if (InStr(txt, "not valid for the Firm") || InStr(txt, "valid Staff ID and Password") || (InStr(txt, "Staff ID") && InStr(txt, "Password") && InStr(txt, "not valid"))) {
            ; Dismiss the error popup
            try ControlClick("OK", "ahk_id " . h, , , , "NA")
            try ControlClick("Button1", "ahk_id " . h, , , , "NA")
            try PostMessage(0x0111, 1, 0, , "ahk_id " . h) ; IDOK
            Send("{Enter}")
            Sleep(300)

            ; Dismiss the login card so the process isn't left hanging
            if (loginHwnd && WinExist("ahk_id " . loginHwnd)) {
                try ControlClick("Cancel", "ahk_id " . loginHwnd, , , , "NA")
                Send("{Esc}")
                Sleep(300)
            } else if (WinExist(winPrefix)) {
                try ControlClick("Cancel", winPrefix, , , , "NA")
                Send("{Esc}")
            }

            UpdateStatus(winPrefix . ": Invalid database credentials.")
            return true
        }
    }
    return false
}
