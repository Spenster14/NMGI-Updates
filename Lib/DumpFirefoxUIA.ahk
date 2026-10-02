#Requires AutoHotkey v2.0
#include <UIA>

if !WinExist("About Mozilla Firefox") {
    MsgBox("Window not found")
    ExitApp()
}

aboutEl := UIA.ElementFromHandle("About Mozilla Firefox")
FileAppend(aboutEl.DumpAll(), A_ScriptDir . "\FirefoxUIA_Dump.txt")
MsgBox("Dump saved to FirefoxUIA_Dump.txt")
