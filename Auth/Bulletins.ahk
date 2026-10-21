#Requires AutoHotkey v2.0
; Auth/Bulletins.ahk - dismisses startup popups (Choose Data Location, User already present, User Bulletin). Moved verbatim from NMGIUpdates.ahk.

; ==============================================================================
; Helper Function to kill popups
; ==============================================================================
HandleBulletins(loops := 5) {
    loop loops {
        Sleep(1000)

        if WinExist("Choose Data Location") {
            WinActivate("Choose Data Location")
            try {
                UIA.ElementFromHandle("Choose Data Location").FindElement({ Name: "OK", Type: "Button" }).Click()
            } catch {
                Send("{Enter}")
            }
        }

        if WinExist("User already present") {
            WinActivate("User already present")
            try {
                UIA.ElementFromHandle("User already present").FindElement({ Name: "OK", Type: "Button" }).Click()
            } catch {
                Send("{Enter}") ; Fallback to pressing Enter on the OK button
            }
        }

        if WinExist("User Bulletin") {
            WinActivate("User Bulletin")
            try {
                UIA.ElementFromHandle("User Bulletin").FindElement({ Name: "Close", Type: "Button" }).Highlight().Click()
            } catch {
                WinClose("User Bulletin")
            }
        }

        ; If main window is active and no bulletins exist, we can exit early
        /*         if WinActive("UltraTax CS") && !WinExist("User Bulletin") && !WinExist("Onvio")
        continue */
    }
}
