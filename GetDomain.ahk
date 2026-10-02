#Requires AutoHotkey v2.0

compDomain := ""
try {
    wmi := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
    for comp in wmi.ExecQuery("Select Domain from Win32_ComputerSystem")
        compDomain := comp.Domain
} catch {
    compDomain := "WMI Query Failed"
}

userDomain := EnvGet("USERDOMAIN")

; Copy the most likely domain to the clipboard for ease of use
if (compDomain != "WMI Query Failed" && compDomain != "") {
    A_Clipboard := compDomain
} else {
    A_Clipboard := userDomain
}

MsgBox("WMI Domain: " . compDomain . "`n`nEnvironment USERDOMAIN: " . userDomain . "`n`n(The detected domain has been automatically copied to your clipboard!)", "Domain Info")
