#Requires AutoHotkey v2.0
#SingleInstance force

; ==============================================================================
; Self-Elevation Protocol: Ensure Administrative Privileges
; ==============================================================================
if (!A_IsAdmin) {
    isSmokeTest := false
    argStr := ""
    for arg in A_Args {
        if (arg = "/smoke" || arg = "/test")
            isSmokeTest := true
        argStr .= ' "' . arg . '"'
    }

    if (!isSmokeTest) {
        try {
            if A_IsCompiled
                Run('*RunAs "' . A_ScriptFullPath . '" /restart' . argStr)
            else
                Run('*RunAs "' . A_AhkPath . '" /restart "' . A_ScriptFullPath . '"' . argStr)
            ExitApp()
        } catch {
            MsgBox("Administrative privileges are required to run Jacro updates.", "Elevation Required", "Iconx")
            ExitApp()
        }
    }
}
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
#Include <UpdatePractice>
#Include <UpdateLacerte>
#Include Core\Network.ahk
#Include Core\Process.ahk
#Include Core\Logger.ahk
#Include Core\AppRegistry.ahk
#Include Core\Config.ahk
#Include Auth\Bulletins.ahk
#Include Auth\TRLogin.ahk
#Include Auth\LacerteLogin.ahk
#Include <UpdateAdobe>
; #Include <UpdateFPS>
SetTitleMatchMode 2
CoordMode("ToolTip", "Screen")

TodayDate := FormatTime(A_Now, "yyMMdd")
global AppVersion := "V261021"
if (A_IsCompiled) {
    try AppVersion := "V" . FormatTime(FileGetTime(A_ScriptFullPath, "M"), "yyMMdd")
}

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



; Initialize GUI
BuildGUI()

BuildGUI(forceRescan := false) {
    global StatusBox, SortedApps, MyGui, Apps, AppVersion

    if (MyGui != "") {
        MyGui.Destroy()
        MyGui := ""
        StatusBox := ""
    }

    if (forceRescan) {
        ClearHostCache()
        ToolTip("Scanning applications, please wait...", 100, 100)
    }

    FoundApps := []

    for app in Apps {
        app.Path := ResolveAppPath(app, forceRescan)

        if (app.Path != "") {
            app.Status := GetAppStatus(app.Name)
            app.Color := GetColorByStatus(app.Status)
            FoundApps.Push(app)
        }
    }

    SortedApps := SortApps(FoundApps)

    ; ==============================================================================
    ; GUI Setup
    ; ==============================================================================
    MyGui := Gui("+AlwaysOnTop", "Jacro " . AppVersion)
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
        if (!PromptLacerteLogin())
            return
    }

    batchResults := []

    for app in SortedApps {
        if (app.cb.Value) {
            ActiveCheckbox := app

            UpdateStatus("Launching " app.Label "...")
            result := app.fn()

            UpdateStatus("Cleaning up " app.Label "...")
            SplitPath(app.Path, &exeName)
            if (exeName) {
                TerminateProcessGracefully(exeName, 5, true)
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

            batchResults.Push({ App: app, Result: result, Status: app.Status })

            ActiveCheckbox := ""
            UpdateStatus("Idle...")
        }
    }

    UpdateStatus("Updates complete.")
    ShowSummaryReport(batchResults)
}

ShowSummaryReport(results) {
    if (results.Length == 0)
        return

    updated := []
    current := []
    attention := []
    errors := []

    for item in results {
        if (item.Status == "Updated") {
            updated.Push(item.App.Label)
        } else if (item.Status == "NotUpdated") {
            current.Push(item.App.Label)
        } else if (item.Status == "Error") {
            msg := RegExReplace(item.Result, "^\s*-\s*", "")
            errors.Push(item.App.Label . (msg != "" ? " (" . msg . ")" : ""))
        } else {
            msg := RegExReplace(item.Result, "^\s*-\s*", "")
            attention.Push(item.App.Label . (msg != "" ? " (" . msg . ")" : ""))
        }
    }

    report := "Update batch processing complete.`n`n"
    if (updated.Length > 0) {
        report .= "✔ UPDATED (" . updated.Length . "):`n"
        for name in updated
            report .= "  • " . name . "`n"
        report .= "`n"
    }
    if (current.Length > 0) {
        report .= "✔ ALREADY UP-TO-DATE (" . current.Length . "):`n"
        for name in current
            report .= "  • " . name . "`n"
        report .= "`n"
    }
    if (attention.Length > 0) {
        report .= "⚠ ATTENTION REQUIRED (" . attention.Length . "):`n"
        for name in attention
            report .= "  • " . name . "`n"
        report .= "`n"
    }
    if (errors.Length > 0) {
        report .= "✖ ERRORS (" . errors.Length . "):`n"
        for name in errors
            report .= "  • " . name . "`n"
        report .= "`n"
    }

    iconOpt := (errors.Length > 0) ? "Icon!" : ((attention.Length > 0) ? "Icon!" : "Iconi")
    MsgBox(report, "Jacro - Batch Update Summary", iconOpt)
}

CloseApp(*) {
    ExitApp
}

$Esc::
{
    ExitApp()
}
