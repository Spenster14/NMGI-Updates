#Requires AutoHotkey v2.0
#SingleInstance force
#include <UIA>
#include <UIA_Browser>
#include <OCR>
#Include <UpdateChrome>
#Include <UpdateEdge>
#Include <UpdateQB>
#Include <UpdateUT>
#Include <UpdateFileCabinet>
#Include <UpdateFirefox>
#Include <UpdateFixedAssets>
#Include <UpdateAccountingCS>
#Include <UpdateLacerte>
#Include Core\Logger.ahk
/* #Include <UpdateAdobe>
#Include <UpdateFPS> */
SetTitleMatchMode 2
CoordMode("ToolTip", "Screen")

TodayDate := FormatTime(A_Now, "yyMMdd")

; ==============================================================================
; Helper Functions & Globals
; ==============================================================================

global StatusBox := ""
global ActiveCheckbox := ""
global FlashState := 0
global SortedApps := []
global MyGui := ""
global LacerteEmail := ""
global LacertePassword := ""

UpdateStatus(msg := "", args*) {
    global StatusBox
    try {
        if !IsSet(StatusBox) || !StatusBox
            return
        if (msg == "")
            StatusBox.Value := "Idle..."
        else
            StatusBox.Value := msg
    }
}

FlashActiveCheckbox() {
    global ActiveCheckbox, FlashState
    try {
        if !ActiveCheckbox || !ActiveCheckbox.txt
            return
        FlashState := !FlashState
        if (FlashState)
            ActiveCheckbox.txt.Opt("cFF8C00") ; Orange text for active flashing
        else
            ActiveCheckbox.txt.Opt(ActiveCheckbox.Color)
        ActiveCheckbox.txt.Redraw()
    }
}

SetTimer(FlashActiveCheckbox, 500)

; ==============================================================================
; Define Applications
; ==============================================================================

global Apps := [{ Name: "Quickbooks Enterprise 22", Label: "QB Enterprise 2022", fn: (*) => QB("22 Enterprise"), pathFn: (*
) => GetQBPath("22 Enterprise") }, { Name: "Quickbooks Enterprise 23", Label: "QB Enterprise 2023", fn: (*) => QB(
    "23 Enterprise"), pathFn: (*) => GetQBPath("23 Enterprise") }, { Name: "Quickbooks Enterprise 24", Label: "QB Enterprise 2024",
        fn: (*) => QB("24 Enterprise"), pathFn: (*) => GetQBPath("24 Enterprise") }, { Name: "Quickbooks Premier 22",
            Label: "QB Premier 2022", fn: (*) => QB("22 Premier"), pathFn: (*) => GetQBPath("22 Premier") }, { Name: "Quickbooks Premier 23",
                Label: "QB Premier 2023", fn: (*) => QB("23 Premier"), pathFn: (*) => GetQBPath("23 Premier") }, { Name: "Quickbooks Premier 24",
                    Label: "QB Premier 2024", fn: (*) => QB("24 Premier"), pathFn: (*) => GetQBPath("24 Premier") }, { Name: "Ultratax 23",
                        Label: "UltraTax 2023", fn: (*) => UT("23"), pathFn: (*) => GetUTPath("23") }, { Name: "Ultratax 24",
                            Label: "UltraTax 2024", fn: (*) => UT("24"), pathFn: (*) => GetUTPath("24") }, { Name: "Ultratax 25",
                                Label: "UltraTax 2025", fn: (*) => UT("25"), pathFn: (*) => GetUTPath("25") }, { Name: "FileCabinet",
                                    Label: "FileCabinet", fn: (*) => FileCabinet(), pathFn: (*) => GetFileCabinetPath() }, { Name: "FixedAssetsCS",
                                        Label: "Fixed Assets CS", fn: (*) => FixedAssets(), pathFn: (*) =>
                                            GetFixedAssetsPath() }, { Name: "AccountingCS", Label: "Accounting CS", fn: (*
                                            ) => AccountingCS(), pathFn: (*) => GetAccountingCSPath() }, { Name: "Lacerte 22",
                                                Label: "Lacerte 2022", fn: (*) => Lacerte("22"), pathFn: (*) =>
                                                    GetLacertePath("22") }, { Name: "Lacerte 23",
                                                        Label: "Lacerte 2023", fn: (*) => Lacerte("23"), pathFn: (*) =>
                                                            GetLacertePath("23") }, { Name: "Lacerte 24",
                                                                Label: "Lacerte 2024", fn: (*) => Lacerte("24"), pathFn: (*
                                                                ) => GetLacertePath("24") }, { Name: "Chrome",
                                                                    Label: "Chrome", fn: (*) => Chrome(), pathFn: (*) =>
                                                                        GetChromePath() }, { Name: "Edge",
                                                                            Label: "Edge", fn: (*) => Edge(), pathFn: (*
                                                                            ) => GetEdgePath() }, { Name: "Firefox",
                                                                                Label: "Firefox", fn: (*) => Firefox(),
                                                                                pathFn: (*) =>
                                                                                    GetFirefoxPath() }
]

; Initialize GUI
BuildGUI()

BuildGUI(forceRescan := false) {
    global StatusBox, SortedApps, MyGui, Apps

    if (MyGui != "") {
        MyGui.Destroy()
        MyGui := ""
        StatusBox := ""
    }

    if (forceRescan) {
        ToolTip("Scanning applications, please wait...", 100, 100)
    }

    iniFile := "GUIsettings.ini"
    FoundApps := []

    for app in Apps {
        if (forceRescan) {
            app.Path := app.pathFn()
            if (app.Path != "") {
                IniWrite(app.Path, iniFile, "Paths", app.Name)
            } else {
                IniWrite("NotInstalled", iniFile, "Paths", app.Name)
            }
        } else {
            cachedPath := IniRead(iniFile, "Paths", app.Name, "")

            if (cachedPath == "NotInstalled") {
                app.Path := ""
            } else if (cachedPath != "" && FileExist(cachedPath)) {
                app.Path := cachedPath
            } else {
                app.Path := app.pathFn()
                if (app.Path != "") {
                    IniWrite(app.Path, iniFile, "Paths", app.Name)
                } else {
                    IniWrite("NotInstalled", iniFile, "Paths", app.Name)
                }
            }
        }

        if (app.Path != "") {
            app.Status := GetAppStatus(app.Name)
            app.Color := GetColorByStatus(app.Status)
            FoundApps.Push(app)
        }
    }

    SortedApps := []
    for app in FoundApps
        SortedApps.Push(app)

    GetAppCategory(appName) {
        if InStr(appName, "UltraTax") || InStr(appName, "FileCabinet") || InStr(appName, "Fixed Assets") || InStr(
            appName, "Accounting")
            return 1
        if InStr(appName, "QB") || InStr(appName, "Quickbooks")
            return 2
        if InStr(appName, "Chrome") || InStr(appName, "Edge") || InStr(appName, "Firefox")
            return 4
        return 3
    }

    ; Sort SortedApps by Category, then alphabetically
    loop SortedApps.Length {
        i := A_Index
        loop SortedApps.Length - i {
            app1 := SortedApps[A_Index]
            app2 := SortedApps[A_Index + 1]
            cat1 := GetAppCategory(app1.Label)
            cat2 := GetAppCategory(app2.Label)

            swap := false
            if (cat1 > cat2) {
                swap := true
            } else if (cat1 == cat2) {
                if (StrCompare(app1.Label, app2.Label) > 0)
                    swap := true
            }

            if (swap) {
                temp := SortedApps[A_Index]
                SortedApps[A_Index] := SortedApps[A_Index + 1]
                SortedApps[A_Index + 1] := temp
            }
        }
    }

    ; ==============================================================================
    ; GUI Setup
    ; ==============================================================================
    MyGui := Gui("+AlwaysOnTop", "Jacro v261008")
    MyGui.SetFont("s10", "Segoe UI")
    MyGui.Add("Text", "xm", "Select the applications to start:")

    col1 := []
    col2 := []
    col3 := []
    numApps := SortedApps.Length

    if (numApps > 0) {
        appsPerCol := Ceil(numApps / 3)
        for i, app in SortedApps {
            if (i <= appsPerCol)
                col1.Push(app)
            else if (i <= appsPerCol * 2)
                col2.Push(app)
            else
                col3.Push(app)
        }

        RenderColumn(col, isFirst := false) {
            opts := isFirst ? "Section" : "ys Section"
            for i, app in col {
                app.cb := MyGui.Add("Checkbox", opts, "")
                app.txt := MyGui.Add("Text", "x+0 yp w130 BackgroundTrans " . app.Color, app.Label)
                if (app.Status == "Updated") {
                    app.txt.SetFont("bold")
                }

                ; Allow clicking the text to toggle the checkbox
                app.txt.OnEvent("Click", ((cb, *) => cb.Value := !cb.Value).Bind(app.cb))

                app.cb.Value := 1
                opts := "xs"
            }
        }

        RenderColumn(col1, true)
        if (col2.Length > 0)
            RenderColumn(col2)
        if (col3.Length > 0)
            RenderColumn(col3)
    } else {
        MyGui.Add("Text", "xm y+10", "No applications found. Click Rescan.")
    }

    ; --- Status Box ---
    if (numApps > 0) {
        lastApp := col1[col1.Length]
        lastApp.txt.GetPos(&cX, &cY, &cW, &cH)
        statusY := cY + cH + 20
        MyGui.Add("Text", "xm y" statusY, "Status:")

        ; Calculate exact width to match the application columns
        rightApp := col3.Length > 0 ? col3[1] : (col2.Length > 0 ? col2[1] : col1[1])
        rightApp.txt.GetPos(&rX, &rY, &rW, &rH)

        ; We need the start X from the very first checkbox
        col1[1].cb.GetPos(&startX)

        boxWidth := (rX + rW) - startX
    } else {
        MyGui.Add("Text", "xm y+15", "Status:")
        boxWidth := 400
    }
    StatusBox := MyGui.Add("Edit", "xm w" boxWidth " h60 ReadOnly", "Idle...")

    ; --- Buttons ---
    btnStart := MyGui.Add("Button", "xm w100 Default", "Start")
    btnRescan := MyGui.Add("Button", "x+10 w100", "Rescan")
    btnCancel := MyGui.Add("Button", "x+10 w100", "Cancel")

    ; Events
    btnStart.OnEvent("Click", RunSelectedApps)
    btnRescan.OnEvent("Click", (*) => BuildGUI(true))

    btnRescan.OnEvent("ContextMenu", UncheckProcessedApps)
    UncheckProcessedApps(ctrl, item, isRightClick, x, y) {
        if (GetKeyState("Shift")) {
            uncheckCount := 0
            for app in SortedApps {
                if (app.Status == "Updated" || app.Status == "NotUpdated") {
                    if (app.cb.Value) {
                        app.cb.Value := 0
                        uncheckCount++
                    }
                }
            }
            UpdateStatus("Unchecked " uncheckCount " processed applications.")
        }
    }

    btnCancel.OnEvent("Click", CloseApp)
    MyGui.OnEvent("Close", CloseApp)

    MyGui.Show("Hide")
    WinGetPos(, , &guiW, &guiH, MyGui.Hwnd)
    primaryMonitor := MonitorGetPrimary()
    MonitorGetWorkArea(primaryMonitor, &MonLeft, &MonTop, &MonRight, &MonBottom)
    newX := MonRight - guiW - 25
    newY := MonBottom - guiH - 25
    WinMove(newX, newY, , , MyGui.Hwnd)
    MyGui.Show("NoActivate")

    if (forceRescan) {
        ToolTip() ; clear tooltip
    }
}

RunSelectedApps(*) {
    global ActiveCheckbox, LacerteEmail, LacertePassword
    saved := MyGui.Submit(0)

    ; --- Lacerte Upfront Login ---
    needsLacerteLogin := false
    for app in SortedApps {
        if (app.cb.Value && InStr(app.Name, "Lacerte")) {
            needsLacerteLogin := true
            break
        }
    }

    if (needsLacerteLogin) {
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
            return
        }
    }

    for app in SortedApps {
        if (app.cb.Value) {
            ActiveCheckbox := app

            UpdateStatus("Launching " app.Label "...")
            result := app.fn()

            UpdateStatus("Cleaning up " app.Label "...")
            SplitPath(app.Path, &exeName)
            if (exeName) {
                ; Universally wait up to 20 seconds for the process to fully exit RAM
                ProcessWaitClose(exeName, 20)
            }

            if (result)
                UpdateLog(app.Name, result)

            app.Status := GetAppStatus(app.Name)
            app.Color := GetColorByStatus(app.Status)
            app.txt.Opt(app.Color)
            if (app.Status == "Updated") {
                app.txt.SetFont("bold")
            } else {
                app.txt.SetFont("norm")
            }
            app.txt.Redraw()

            ActiveCheckbox := ""
            UpdateStatus("Idle...")
        }
    }

    UpdateStatus("Updates are complete. Have a nice day.")
    MsgBox("Updates are complete. Have a nice day.")
}
#Requires AutoHotkey v2.0

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

CloseApp(*) {
    ExitApp
}

$Esc::
{
    ExitApp()
}
