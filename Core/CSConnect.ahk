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
; Identifies the active login modal dialog by inspecting visible process windows for Edit and OK controls.
; Bypasses slow/freezing cross-process UIA tree walks and unstyled WinForms ES_PASSWORD caveats.
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
                hasOk := false
                for c in ctrls {
                    if InStr(c, "Edit")
                        hasEdit := true
                    if InStr(c, "Button") {
                        txt := ""
                        try txt := ControlGetText(c, h)
                        if (txt = "OK" || InStr(txt, "OK") || InStr(txt, "Change password"))
                            hasOk := true
                    }
                }
                if (hasEdit && hasOk) {
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

                editControls := []
                okCtrlHwnd := 0

                for i, c in ctrlNames {
                    if InStr(c, "Edit")
                        editControls.Push(ctrlHwnds[i])
                    if InStr(c, "Button") {
                        txt := ""
                        try txt := ControlGetText(ctrlHwnds[i], "ahk_id " . loginHwnd)
                        if (txt = "OK" || InStr(txt, "OK"))
                            okCtrlHwnd := ctrlHwnds[i]
                    }
                }

                pwdCtrl := 0
                ; Check for standard ES_PASSWORD (0x0020)
                for eh in editControls {
                    s := 0
                    try s := WinGetStyle(eh)
                    if (s & 0x0020) {
                        pwdCtrl := eh
                        break
                    }
                }

                ; Fallback: If 2 edit controls, edit 1 is Staff ID ("ADMIN"), edit 2 is Password
                if (!pwdCtrl && editControls.Length >= 2) {
                    for eh in editControls {
                        val := ""
                        try val := ControlGetText(eh, "ahk_id " . loginHwnd)
                        if (val == "") {
                            pwdCtrl := eh
                            break
                        }
                    }
                    if (!pwdCtrl)
                        pwdCtrl := editControls[2]
                } else if (!pwdCtrl && editControls.Length == 1) {
                    pwdCtrl := editControls[1]
                }

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

                    if (WinWaitClose("ahk_id " . loginHwnd, , 3) || WinExist(winPrefix . " -")) {
                        handledLogin := true
                        break
                    }
                } else {
                    ; UIA fallback on loginHwnd with bounded timeout
                    try {
                        oldTimeout := UIA.TransactionTimeout
                        UIA.TransactionTimeout := 1500
                        dlgEl := UIA.ElementFromHandle(loginHwnd)
                        pwdEl := ""
                        try pwdEl := dlgEl.FindElement({Type: "Edit", IsPassword: true})
                        if (!pwdEl)
                            try pwdEl := dlgEl.FindElement({Name: "Password", Type: "Edit", mm: 2})
                        if (pwdEl) {
                            pwdEl.Click("left")
                            Sleep(100)
                            SendText(dbPassword)
                            Sleep(150)
                            okBtn := ""
                            try okBtn := dlgEl.FindElement({Name: "OK", Type: "Button", mm: 2})
                            if (okBtn)
                                okBtn.Click()
                            else
                                Send("{Enter}")
                            UIA.TransactionTimeout := oldTimeout
                            if (WinWaitClose("ahk_id " . loginHwnd, , 3) || WinExist(winPrefix . " -")) {
                                handledLogin := true
                                break
                            }
                        }
                        UIA.TransactionTimeout := oldTimeout
                    }
                }
            }
            Sleep(500)
        }

        ; Last-resort fallback: keyboard navigation
        if (!handledLogin && WinExist(winPrefix) && !WinExist(winPrefix . " -")) {
            WinActivate(winPrefix)
            Send("{Tab 2}")
            Sleep(200)
            SendText(dbPassword)
            Sleep(200)
            Send("{Enter}")
        }
    }

    UpdateStatus("Waiting for " . winPrefix . " dashboard to load...", 100, 100)
    WinWait(winPrefix . " -", , 120)
    WinActivate(winPrefix . " -")
    WinMaximize(winPrefix . " -")
    return true
}
