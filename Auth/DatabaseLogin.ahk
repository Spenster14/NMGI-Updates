#Requires AutoHotkey v2.0
; Auth/DatabaseLogin.ahk - Upfront prompt for application credentials.
; Gathers passwords/credentials in a single window for checked apps (Accounting CS, Practice CS, FPS, Lacerte).
; Sets in-memory globals: AcsPassword, PracticePassword, FpsPassword, LacerteEmail, LacertePassword.
; Returns true on success or if no credential apps were selected; false if cancelled.

global AcsPassword := ""
global PracticePassword := ""
global FpsPassword := ""
global LacerteEmail := ""
global LacertePassword := ""

PromptDatabasePasswords(appList) {
    global AcsPassword, PracticePassword, FpsPassword, LacerteEmail, LacertePassword

    needsAcs := false
    needsPractice := false
    needsFps := false
    needsLacerte := false

    for app in appList {
        if (!app.cb.Value)
            continue
        if (app.Name = "AccountingCS")
            needsAcs := true
        else if (app.Name = "PracticeCS")
            needsPractice := true
        else if (app.Name = "FPS")
            needsFps := true
        else if (InStr(app.Name, "Lacerte"))
            needsLacerte := true
    }

    ; If none of the credential-requiring apps are checked, proceed immediately
    if (!needsAcs && !needsPractice && !needsFps && !needsLacerte)
        return true

    dbGui := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", "Application Credentials")
    dbGui.SetFont("s10", "Segoe UI")
    dbGui.Add("Text", "w320", "Enter credentials for the selected applications (leave blank if none):")

    editAcs := ""
    editPractice := ""
    editFps := ""
    editLacerteEmail := ""
    editLacertePassword := ""

    if (needsAcs) {
        dbGui.Add("Text", "w320 y+12", "Accounting CS Password:")
        editAcs := dbGui.Add("Edit", "w320 Password")
    }

    if (needsPractice) {
        dbGui.Add("Text", "w320 y+12", "Practice CS Password:")
        editPractice := dbGui.Add("Edit", "w320 Password")
    }

    if (needsFps) {
        dbGui.Add("Text", "w320 y+12", "FPS Password:")
        editFps := dbGui.Add("Edit", "w320 Password")
    }

    if (needsLacerte) {
        dbGui.Add("Text", "w320 y+12", "Lacerte Email:")
        editLacerteEmail := dbGui.Add("Edit", "w320", LacerteEmail)
        dbGui.Add("Text", "w320 y+10", "Lacerte Password:")
        editLacertePassword := dbGui.Add("Edit", "w320 Password", LacertePassword)
    }

    submitted := false
    SubmitPasswords(*) {
        if (needsAcs && editAcs)
            AcsPassword := editAcs.Value
        if (needsPractice && editPractice)
            PracticePassword := editPractice.Value
        if (needsFps && editFps)
            FpsPassword := editFps.Value
        if (needsLacerte) {
            if (editLacerteEmail)
                LacerteEmail := editLacerteEmail.Value
            if (editLacertePassword)
                LacertePassword := editLacertePassword.Value
        }
        submitted := true
        dbGui.Destroy()
    }

    btnSubmit := dbGui.Add("Button", "w100 y+18 Default", "Submit")
    btnCancel := dbGui.Add("Button", "w100 x+10 yp", "Cancel")

    btnSubmit.OnEvent("Click", SubmitPasswords)
    btnCancel.OnEvent("Click", (*) => dbGui.Destroy())
    dbGui.OnEvent("Close", (*) => dbGui.Destroy())
    dbGui.OnEvent("Escape", (*) => dbGui.Destroy())

    dbGui.Show()
    WinWaitClose(dbGui.Hwnd)

    if (!submitted) {
        MsgBox("Credential prompt was cancelled. Aborting updates.")
        return false
    }

    ; Check if any required credential was left blank
    if ((needsAcs && AcsPassword == "") || (needsPractice && PracticePassword == "") || (needsFps && FpsPassword == "") || (needsLacerte && (LacerteEmail == "" || LacertePassword == ""))) {
        result := MsgBox("One or more credentials were left blank. Do you want to continue anyway?", "Blank Credential Warning", "YesNo Icon!")
        if (result == "No")
            return false
    }

    return true
}
