#Requires AutoHotkey v2.0
; Auth/DatabaseLogin.ahk - Upfront prompt for application database passwords.
; Gathers passwords in a single window for checked apps (Accounting CS, Practice CS, FPS).
; Sets in-memory globals: AcsPassword, PracticePassword, FpsPassword.
; Returns true on success or if no database apps were selected; false if cancelled.

global AcsPassword := ""
global PracticePassword := ""
global FpsPassword := ""

PromptDatabasePasswords(appList) {
    global AcsPassword, PracticePassword, FpsPassword

    needsAcs := false
    needsPractice := false
    needsFps := false

    for app in appList {
        if (!app.cb.Value)
            continue
        if (app.Name = "AccountingCS")
            needsAcs := true
        else if (app.Name = "PracticeCS")
            needsPractice := true
        else if (app.Name = "FPS")
            needsFps := true
    }

    ; If none of the 3 database apps are checked, proceed immediately
    if (!needsAcs && !needsPractice && !needsFps)
        return true

    dbGui := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", "Database Passwords")
    dbGui.SetFont("s10", "Segoe UI")
    dbGui.Add("Text", "w320", "Enter database passwords for the selected applications:")

    editAcs := ""
    editPractice := ""
    editFps := ""

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

    submitted := false
    SubmitPasswords(*) {
        if (needsAcs && editAcs)
            AcsPassword := editAcs.Value
        if (needsPractice && editPractice)
            PracticePassword := editPractice.Value
        if (needsFps && editFps)
            FpsPassword := editFps.Value
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
        MsgBox("Database password prompt was cancelled. Aborting updates.")
        return false
    }

    ; Check if any required password was left blank
    if ((needsAcs && AcsPassword == "") || (needsPractice && PracticePassword == "") || (needsFps && FpsPassword == "")) {
        result := MsgBox("One or more passwords were left blank. Do you want to continue anyway?", "Blank Password Warning", "YesNo Icon!")
        if (result == "No")
            return false
    }

    return true
}
