#Requires AutoHotkey v2.0
#SingleInstance force
#include <UIA>
#include <UIA_Browser>
loop {
                chromeEl := UIA.ElementFromHandle("ahk_exe chrome.exe")
            ; try {
            ; Check Success
/*             if chromeEl.FindElement({Name:"Chrome is up to date", Type:"Text"}).Highlight() {
                ToolTip()
                MsgBox("No Update")
                return
            } */

            ; Check Restart
            if chromeEl.FindElement({Name:"Nearly up to date! Relaunch Chrome to finish updating.", Type:"Text"}) {
            MsgBox("Found Update")
            chromeEl.FindElement({Name:"Relaunch", Type:"Button"}).Highlight().ControlClick("left")
            }
            ; } catch {
                ;loop
            ; }
            Sleep(1000)

}
exitapp