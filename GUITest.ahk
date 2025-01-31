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
CoordMode("ToolTip","Screen")

ClientList := Map()
Loop Read, "GUIsettings.ini"
{
	SplitKey := StrSplit(A_LoopReadLine,"|")
	ClientList[StrLower(SplitKey[1])] := StrSplit(SplitKey[2],",")
}

myGui := Constructor()
myGui.Show("w230 h264")


PopulateGUI()
{
	DropDownList1.Delete()
	for key,pair in ClientList
		DropDownList1.Add([key])
	DropDownList1.Choose(GetDomainName())
	PopulateListView()
}

PopulateListView(*)
{
	LV_.Delete()
	for each in ClientList[ControlGetChoice(DropDownList1)]
		LV_.Add(,each)
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

Constructor()
{	
	myGui := Gui()
	ButtonBtnStart := myGui.Add("Button", "vBtnStart x136 y48 w80 h49", "&Start")
	Global LV_ := myGui.Add("ListView", "x8 y40 w120 h214 +LV0x4000 -hdr", ["Items to Update"])
	Global DropDownList1 := myGui.Add("DropDownList", "x8 y8 w120 Sort Lowercase", ["DropDownList", "", ""])
	ButtonRemove := myGui.Add("Button", "x136 y104 w80 h52", "&Remove")
	PopulateGUI()
	LV_.OnEvent("DoubleClick", LV_DoubleClick)
	ButtonBtnStart.OnEvent("Click", StartFunctions)
	DropDownList1.OnEvent("Change", PopulateListView)
	ButtonRemove.OnEvent("Click", LV_DoubleClick)
	myGui.OnEvent('Close', (*) => ExitApp())
	myGui.Title := "Window"
	
	LV_DoubleClick(LV, RowNum)
	{
		RowNum := LV_.GetNext(0)
		if RowNum == 0
			return
		LV_.Delete(RowNum)
	}
	
	StartFunctions(*)
	{
		FileAppend("- WR to " . A_ComputerName . "`n","output.txt")
		Loop LV_.GetCount()
		{
			%SubStr(LV_.GetText(A_Index),1,InStr(LV_.GetText(A_Index),"(")-1)%(Trim(SubStr(LV_.GetText(A_Index),InStr(LV_.GetText(A_Index),"(")),"()"))
		}
		FileAppend("END`n","output.txt")
		ExitApp
	}
	
	return myGui
}

TestFunc(*)
{
	Msgbox "Testing Func"
	return "Testing Func - Tested Positive`n"
}

RemoveOutput(RemoveLine){
	UpdateText := FileRead("output.txt")
    FileMove("output.txt","output.bak",true)
	loop parse UpdateText,"`n"
		if A_LoopField
			if !InStr(A_LoopField,RemoveLine)
				FileAppend(A_LoopField . "`n","output.txt")
}

$Esc::
{
    ExitApp()
}