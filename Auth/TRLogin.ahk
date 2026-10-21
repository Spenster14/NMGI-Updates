#Requires AutoHotkey v2.0
; Auth/TRLogin.ahk - Thomson Reuters CS sign-in flow (upfront credential prompt, Onvio/Sign-in handling). Moved verbatim from NMGIUpdates.ahk.

TRLogin() {
    ; --- 1. Initiate Sign In --------------------------------------------------
    WinWait("Sign In | Firm ID")
    WinActivate("Sign In | Firm ID")
    Sleep(2500)

    try {
        UIA.ElementFromHandle("Sign In | Firm ID").WaitElement({ AutomationId: "SignInButton" }, 10000).ControlClick()
    } catch {
        MsgBox("Error: Could not find the initial 'Sign In' button.")
        return
    }

    ; --- 2. Smart Wait (The Fix) ----------------------------------------------
    ; Create a group containing BOTH potential next windows
    GroupAdd("TRLoginGroup", "Onvio")       ; The success window
    GroupAdd("TRLoginGroup", "Sign in to")  ; The login required window

    ; Wait for EITHER window to appear.
    ; This returns immediately as soon as one is found.
    ; (Added a 30s timeout just to prevent infinite hanging if app crashes)
    if !WinWait("ahk_group TRLoginGroup", , 30) {
        MsgBox("Error: Timed out waiting for Onvio or Login screen.")
        return
    }

    ; Check which one appeared
    if WinExist("Onvio") {
        Sleep(4000)
        WinClose("Onvio")
        CloseSignInTR()
        return ; Success! We are already logged in.
    }

    ; --- 3. Manual Login Flow -------------------------------------------------
    ; If we are here, the "Sign in to" window must be the one that appeared
    loginTitle := "Sign in to"
    WinActivate(loginTitle)

    userEmail := "", userPass := "", mfaCode := ""

    ; Create a single prompt for all credentials
    credGui := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", "TR Login")
    credGui.Add("Text", "w250", "Please enter your credentials:")
    credGui.Add("Text", "w250 y+10", "Email:")
    emailEdit := credGui.Add("Edit", "w250")
    credGui.Add("Text", "w250 y+10", "Password:")
    passEdit := credGui.Add("Edit", "w250 Password")
    credGui.Add("Text", "w250 y+10", "MFA Code:")
    mfaEdit := credGui.Add("Edit", "w250")
    btn := credGui.Add("Button", "w100 y+15 Default", "Submit")

    SubmitCreds(*) {
        userEmail := emailEdit.Value
        userPass := passEdit.Value
        mfaCode := mfaEdit.Value
        credGui.Destroy()
    }
    btn.OnEvent("Click", SubmitCreds)

    credGui.Show()
    WinWaitClose(credGui.Hwnd)

    if (userEmail == "" || userPass == "" || mfaCode == "") {
        MsgBox("Login cancelled or incomplete.")
        return
    }

    try {
        loginEl := UIA.ElementFromHandle(loginTitle)

        ; A. Enter Email
        loginEl.WaitElement({ Name: "Email", Type: "Edit" }).Value := userEmail
        loginEl.WaitElement({ Name: "Sign in", Type: "Button" }).Click()

        ; B. Enter Password
        passEl := loginEl.WaitElement({ Name: "Password", Type: "Edit" })
        passEl.Value := userPass
        loginEl.WaitElement({ Name: "Sign in", Type: "Button" }).Click()

        ; C. Enter MFA Code
        mfaEl := loginEl.WaitElement({ Name: "Enter your one-time code", Type: "Edit" })
        mfaEl.Value := mfaCode

        if WinExist("Enter your one")
            WinActivate("Enter your one")

        loginEl.FindElement({ Name: "Continue", Type: "Button" }).Click()

        Sleep(2000)

    } catch as err {
        MsgBox("Login Error: " . err.Message)
    }

    if WinExist("Onvio") {
        Sleep(3000)
        WinClose("Onvio")
        CloseSignInTR()
    }
}

CloseSignInTR(*) {
    if WinWaitClose("Sign In | Firm ID", , 10) {
        return
    }
    else {
        UIA.ElementFromHandle("Sign In | Firm ID").WaitElement({ Name: "Try again", Type: "Link" }, 2000).ControlClick()
        Sleep(10000)
        if WinExist("Onvio") {
            Sleep(4000)
            WinClose("Onvio")
            CloseSignInTR()
            return ; Success! We are already logged in.
        }
        ;MsgBox("Timed out! Sign in window is still open.  Exiting app.  Please manually correct")
        ;ExitApp
    }
}
