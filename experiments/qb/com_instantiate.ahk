#Requires AutoHotkey v2.0
#SingleInstance Force
; Step 6.2 - Instantiate Intuit update COM objects. NO update calls are made.
; Appends results to com_instantiate.txt (next to this script).

out := A_ScriptDir "\com_instantiate.txt"
targets := [
    ["Agent2003",               "QBDAgent2003.Agent2003.1",             "{20A10BD4-0FF4-45e8-87EF-D2708E99CEAA}"],
    ["ChNotify",                "QBDAgent.ChNotify.1",                  "{20A10BD7-FF8F-4eb0-9754-7F9641B35BB5}"],
    ["ServiceManager2003",      "QBDServiceMgr2003.ServiceManager2003.1","{D83A0655-59E2-44a5-B1F0-CB07B9B972F2}"],
    ["Services2003",            "QBDServiceMgr2003.Services2003.1",      "{D83A0656-565B-47b1-A1BC-42F700061A72}"],
    ["InstalledInstanceFinder", "QBInstanceFinder.InstalledInstanceFinder.1", "{77AD5847-AE1B-4193-9F15-6E9B2D811E4D}"],
    ["InstanceFinderUtil",      "QBInstanceFinder.InstanceFinderUtil.1", "{7A669A0C-0813-4bf1-A723-26B79C5E9DDC}"]
]

report := "== AHK " A_AhkVersion " (" (A_PtrSize = 8 ? "64-bit" : "32-bit") ") on " A_ComputerName " at " A_Now " ==`n"

for t in targets {
    label := t[1]
    progId := t[2]
    clsid := t[3]
    obj := ""

    ; Attempt 1: via ProgID
    success := false
    errMsg := ""
    try {
        obj := ComObject(progId)
        nm := "", iid := ""
        try nm := ComObjType(obj, "Name")
        try iid := ComObjType(obj, "IID")
        report .= label " (ProgID: " progId "): OK [typeName=" nm ", iid=" iid "]`n"
        success := true
    } catch as e {
        num := ""
        try num := Format("0x{:X}", e.Number)
        errMsg := e.Message " (" num ")"
    }

    ; Attempt 2: fallback to CLSID if ProgID failed
    if (!success) {
        try {
            obj := ComObject(clsid)
            nm := "", iid := ""
            try nm := ComObjType(obj, "Name")
            try iid := ComObjType(obj, "IID")
            report .= label " (CLSID: " clsid "): OK [typeName=" nm ", iid=" iid "] (ProgID failed: " errMsg ")`n"
            success := true
        } catch as e2 {
            num2 := ""
            try num2 := Format("0x{:X}", e2.Number)
            report .= label ": FAIL ProgID [" errMsg "] / CLSID [" e2.Message " (" num2 ")]`n"
        }
    }
    obj := ""
}

report .= "`n"
FileAppend(report, out, "UTF-8")
ExitApp(0)
