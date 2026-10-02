#Requires Autohotkey v2
#SingleInstance force
#include <UIA>
#include <UIA_Browser>
#include <OCR>
#Include <UpdateChrome>
#Include <UpdateFirefox>
#Include <UpdateEdge>
#Include <UpdateAdobe>
#Include <UpdateQB>
#Include <UpdateUT>
#Include <UpdateFileCabinet>
#Include <UpdateFixedAssets>
#Include <UpdateFPS>
SetTitleMatchMode 2
CoordMode("ToolTip", "Screen")

TodayDate := FormatTime(A_Now, "yyMMdd")

ClientList := Map()
loop read, "GUIsettings.ini" {
    SplitKey := StrSplit(A_LoopReadLine, "|")
    ClientList[StrLower(SplitKey[1])] := StrSplit(SplitKey[2], ",")
}

myGui := Constructor()
myGui.Show("w230 h264")

PopulateGUI() {
    DropDownList1.Delete()
    for key, pair in ClientList
        DropDownList1.Add([key])
    DropDownList1.Choose(GetDomainName())
    PopulateListView()
}

PopulateListView(*) {
    LV_.Delete()
    for each in ClientList[ControlGetChoice(DropDownList1)]
        LV_.Add(, each)
}

GetDomainName() {
    ; Create WMI COM object
    wmi := ComObjGet("winmgmts:\\.\root\cimv2")
    ; Query for the domain
    for domain in wmi.ExecQuery("SELECT Domain FROM Win32_ComputerSystem") {
        return StrLower(domain.Domain)
    }
    return "Domain not found."
}

Constructor() {
    myGui := Gui()
    ButtonBtnStart := myGui.Add("Button", "vBtnStart x136 y48 w80 h49", "&Start")
    global LV_ := myGui.Add("ListView", "x8 y40 w120 h214 +LV0x4000 -hdr", ["Items to Update"])
    global DropDownList1 := myGui.Add("DropDownList", "x8 y8 w120 Sort Lowercase", ["DropDownList", "", ""])
    ButtonRemove := myGui.Add("Button", "x136 y104 w80 h52", "&Remove")
    PopulateGUI()
    LV_.OnEvent("DoubleClick", LV_DoubleClick)
    ButtonBtnStart.OnEvent("Click", StartFunctions)
    DropDownList1.OnEvent("Change", PopulateListView)
    ButtonRemove.OnEvent("Click", LV_DoubleClick)
    myGui.OnEvent('Close', (*) => ExitApp())
    myGui.Title := "Jacro Version 0.12"

    global StartGUI := 30
    SetTimer(UpdateTimer, 1000)

    LV_DoubleClick(LV, RowNum) {
        RowNum := LV_.GetNext(0)
        if RowNum == 0
            return
        LV_.Delete(RowNum)
    }

    StartFunctions(*) {
        FileAppend("- WR to " . A_ComputerName . "`r`n", TodayDate . "-Update.log")
        loop LV_.GetCount() {
            %SubStr(LV_.GetText(A_Index), 1, InStr(LV_.GetText(A_Index), "(") - 1)%(Trim(SubStr(LV_.GetText(A_Index),
            InStr(LV_.GetText(A_Index), "(")), "()"))
        }
        FileAppend("END`r`n", TodayDate . "-Update.log")
        if FileExist("output.bak")
            FileDelete("output.bak")
        MsgBox("Updates are complete.  Have a nice day.")
        ExitApp
    }

    return myGui
}

~*::  ; Any key
~LButton::  ; Left click
~RButton::  ; Right click
~MButton::  ; Middle click
{
    SetTimer(UpdateTimer, 0)
    ToolTip
    return
}

UpdateTimer() {
    global StartGUI
    StartGUI--
    if (StartGUI >= 0)
        ToolTip("Countdown before autostart: " . StartGui, 100, 100)
    else {
        SetTimer(UpdateTimer, 0)
        ToolTip
        ControlClick("Button1", "Jacro")
    }
}

TestFunc(*) {
    Msgbox "Testing Func"
    return "Testing Func - Tested Positive`r`n"
}

RemoveOutput(RemoveLine) {
    UpdateText := FileRead(TodayDate . "-Update.log")
    FileMove(TodayDate . "-Update.log", "output.bak", true)
    loop parse UpdateText, "`r`n"
        if A_LoopField
            if !InStr(A_LoopField, RemoveLine)
                FileAppend(A_LoopField . "`r`n", TodayDate . "-Update.log")
}

TRLogin() {
    WinWait "Sign In | Firm ID"
    WinActivate
    UIA.ElementFromHandle("Sign In | Firm ID").WaitElement({ AutomationId: "SignInButton" }).Click()
    if WinWait("Onvio", , 15)								;  15 second test to see if we're already logged in
    {
        ; do nothing
    }
    else {
        WinWait "Sign in to"
        WinActivate
        UIA.ElementFromHandle("Sign in to CS Professional Suite").WaitElement({ Name: "Email", Type: "Edit" }).Value :=
        InputBox("Please enter the user name.", "User Name").Value
        WinActivate "Sign in to"
        UIA.ElementFromHandle("Sign in to CS Professional Suite").WaitElement({ Name: "Sign in", Type: "Button" }).Click(
            "left")
        UIA.ElementFromHandle("Sign in to CS Professional Suite").WaitElement({ Name: "Password", Type: "Edit" }).Value :=
        InputBox("Please enter the user password.", "User password", "password").Value
        WinActivate "Sign in to"
        UIA.ElementFromHandle("Sign in to CS Professional Suite").FindElement({ Name: "Sign in", Type: "Button" }).Click(
            "left")
        UIA.ElementFromHandle("Sign in to CS Professional Suite").WaitElement({ Name: "Enter your one-time code", Type: "Edit" })
        .Value := InputBox("Please enter the one-time code.", "One-time code").Value
        WinActivate "Enter your one"
        UIA.ElementFromHandle("Enter your one").FindElement({ Name: "Continue", Type: "Button" }).Click("left")
        Sleep 2000
    }
    Sleep 3000
}

$Esc::
{
    ExitApp()
}
