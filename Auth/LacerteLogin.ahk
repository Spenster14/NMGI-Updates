#Requires AutoHotkey v2.0
; Auth/LacerteLogin.ahk - upfront Lacerte credential prompt. Extracted from RunSelectedApps in NMGIUpdates.ahk.
; Sets the globals LacerteEmail / LacertePassword (read by Lib/UpdateLacerte.ahk).
; Returns true when both were provided, false if the prompt was cancelled or incomplete.

PromptLacerteLogin() {
    global LacerteEmail, LacertePassword

    lacerteGui := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", "Lacerte Login")
    lacerteGui.Add("Text", "w250", "Lacerte requires authentication.")
    lacerteGui.Add("Text", "w250 y+10", "Email:")
    lEmailEdit := lacerteGui.Add("Edit", "w250")
    lacerteGui.Add("Text", "w250 y+10", "Password:")
    lPassEdit := lacerteGui.Add("Edit", "w250 Password")
    btnLacerte := lacerteGui.Add("Button", "w100 y+15 Default", "Submit")

    SubmitLacerte(*) {
        LacerteEmail := lEmailEdit.Value
        LacertePassword := lPassEdit.Value
        lacerteGui.Destroy()
    }
    btnLacerte.OnEvent("Click", SubmitLacerte)

    lacerteGui.Show()
    WinWaitClose(lacerteGui.Hwnd)

    if (LacerteEmail == "" || LacertePassword == "") {
        MsgBox("Lacerte login cancelled or incomplete. Aborting updates.")
        return false
    }
    return true
}
