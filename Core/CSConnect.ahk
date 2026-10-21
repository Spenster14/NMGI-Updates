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
