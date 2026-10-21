#Requires AutoHotkey v2.0
; ==============================================================================
; QuickBooks Updater Script
; ==============================================================================

GetQBConfig(QBversion) {
    static QB_CONFIG := Map(
        "21 Enterprise", {Name: "QuickBooks Enterprise Solutions 21.0", Exe: ["QBW32EnterpriseAccountant.exe", "QBW32Enterprise.exe"]},
        "22 Enterprise", {Name: "QuickBooks Enterprise Solutions 22.0", Exe: ["QBWEnterpriseAccountant.exe", "QBWEnterprise.exe"]},
        "23 Enterprise", {Name: "QuickBooks Enterprise Solutions 23.0", Exe: ["QBWEnterpriseAccountant.exe", "QBWEnterprise.exe"]},
        "24 Enterprise", {Name: "QuickBooks Enterprise Solutions 24.0", Exe: ["QBWEnterpriseAccountant.exe", "QBWEnterprise.exe"]},
        "21 Premier",    {Name: "QuickBooks 2021",                   Exe: "QBW32Pro.exe"},
        "22 Premier",    {Name: "QuickBooks 2022",                   Exe: ["QBWPremierAccountant.exe", "QBWPremier.exe", "QBWPro.exe"]},
        "23 Premier",    {Name: "QuickBooks 2023",                   Exe: ["QBWPremierAccountant.exe", "QBWPremier.exe", "QBWPro.exe"]},
        "24 Premier",    {Name: "QuickBooks 2024",                   Exe: ["QBWPremierAccountant.exe", "QBWPremier.exe", "QBWPro.exe"]},
        "23 Pro",        {Name: "QuickBooks 2023",                   Exe: "QBWPro.exe"},
        "24 Pro",        {Name: "QuickBooks 2024",                   Exe: "QBWPro.exe"}
    )
    if QB_CONFIG.Has(QBversion)
        return QB_CONFIG[QBversion]
    return ""
}

GetQBPath(QBversion) {
    cfg := GetQBConfig(QBversion)
    if (cfg = "")
        return ""
    
    QBLongName := cfg.Name
    exes := (Type(cfg.Exe) = "Array") ? cfg.Exe : [cfg.Exe]
    
    for exeName in exes {
        if FileExist("C:\Program Files\Intuit\" . QBLongName . "\" . exeName)
            return "C:\Program Files\Intuit\" . QBLongName . "\" . exeName
        else if FileExist("C:\Program Files (x86)\Intuit\" . QBLongName . "\" . exeName)
            return "C:\Program Files (x86)\Intuit\" . QBLongName . "\" . exeName
    }
    return ""
}

QB(QBversion)
{
    ; --- Configuration --------------------------------------------------------
    cfg := GetQBConfig(QBversion)
    if (cfg = "") {
        MsgBox("Error: Unknown QuickBooks version '" . QBversion . "' passed to function.")
        return " - Error (Invalid version)"
    }

    QBLongName := cfg.Name
    QBExe      := cfg.Exe
    
    ; --- Initialization -------------------------------------------------------
    foundUpdate  := false
    previousLine := ""
    
    KillQBTasks()
    QBCreateINI(EnvGet("LocalAppData") . "\Intuit\" . QBLongName . "\QBWUSER.INI")

    ; --- Launch QuickBooks ----------------------------------------------------
    UpdateStatus("Waiting for QuickBooks to open...", 100, 100)
    
    qbPath := GetQBPath(QBversion)
    if (qbPath = "") {
        MsgBox("Could not find install location for " . QBLongName . ". Please check installation.")
        return " - Error (Path not found)"
    }
    
    Run(qbPath)

    ; Start monitoring for the IE popup in the background every 500ms
    SetTimer(HandleIEPopup, 500)

    ; --- Handle Startup & Installers ------------------------------------------
    WinWait("QuickBooks ")
    UpdateStatus() ; Clear tooltip

    ; 1. Handle Major Upgrade / Install Prompt
    if WinExist("QuickBooks ", "Install ") {
        WinActivate
        qbEl := UIA.ElementFromHandle("QuickBooks")
        
        try {
            qbEl.WaitElement({Name:"Install Now", Type:"Pane"}).Click("left")
            WinWait("QuickBooks", "restart your computer")
            
            qbEl := UIA.ElementFromHandle("QuickBooks") ; Refresh handle
            qbEl.WaitElement({Name:"Yes", Type:"Button"}).Click("left") ; Reboot confirmation
            return " - Updates installed"
        } catch {
            ; Logic to handle if elements aren't found could go here
        }
    }

    ; 2. Standard Update Process
    WinWait("QuickBooks ",,,"Service") ; Exclude 'Service' windows
    Sleep(4000) ; Wait for QB to settle and allow background timer to handle popups
    WinActivate
    WinMaximize
    
    ; Retry getting the UIA element, as QB might be unresponsive while loading
    qbEl := ""
    loop 30 {
        try {
            qbEl := UIA.ElementFromHandle("QuickBooks")
            if qbEl
                break
        } catch {
            Sleep(1000)
        }
    }
    
    if !qbEl {
        SetTimer(HandleIEPopup, 0)
        MsgBox("Timed out waiting for QuickBooks UI to become responsive.")
        return " - Error (UI Timeout)"
    }
    
    ; Give the timer one last chance to kill it before we send keystrokes
    if WinExist("Upgrade Internet Explorer")
        Sleep(1000)
        
    Send("!hd") ; Open Help Menu -> Update
    
    ; Navigate Update Menu
    try {
        qbEl.WaitElement({Name:"Update Now", Type:"Pane"}).Click("left")
        qbEl.WaitElement({Name:"Get Updates", Type:"Pane"}).Click("left")
    } catch as err {
        SetTimer(HandleIEPopup, 0) ; Stop timer on error
        MsgBox("Failed to navigate Update UI: " . err.Message)
        return " - Error (UI Navigation)"
    }

    SetTimer(HandleIEPopup, 0) ; Stop timer once we successfully navigated
    Sleep(2000)

    ; --- Define OCR Area ------------------------------------------------------
    ; We are looking at the progress bar text area
    try {
        qbWindowEl := qbEl.WaitElement({Name:"Update QuickBooks Desktop", Type:"Window"})
        qbLoc := qbWindowEl.Location
        
        ; Calculate ROI (Region of Interest) based on window geometry
        roiX := qbLoc.x
        roiY := qbLoc.y + (qbLoc.h * (2/3)) ; Start 2/3rds down the window
        roiW := qbLoc.w * 0.6               ; Look at left 60%
        roiH := qbLoc.h / 3                 ; Look at bottom 1/3rd
    } catch {
        MsgBox("Could not locate Update Window geometry.")
        return " - Error (Window Geometry)"
    }

    ; --- Monitoring Loop ------------------------------------------------------
    Loop {
        Sleep(1000)
        
        ; OCR Scan
        try {
            result := OCR.FromRect(roiX, roiY, roiW, roiH,, 2)
            currentText := result.Text
        } catch {
            currentText := ""
        }
        
        UpdateStatus("Currently sees: " . currentText . "`nPrevious: " . previousLine, 100, 100)

        ; Case A: Update Progress Detected
        if (InStr(currentText, "%") && !foundUpdate) {
            foundUpdate := true
        }
        
        ; Case B: Update Complete
        else if (InStr(currentText, "Update Complete")) {
            Sleep(500)
            
            ; Handle "Restart Required" popup inside the app
            if WinExist("QuickBooks Desktop Information") {
                WinActivate("QuickBooks Desktop Information")
                Send("{Space}") ; Close popup
                WinWait("QuickBooks ",,,"Service")
                WinActivate("QuickBooks ",,,"Service")
                
                ; Close Update Window
                qbEl.FindElement({Name:"Close", Type:"Pane"}).Click("left")
                WinClose("QuickBooks")
                
                QBWaitClose(QBversion, QBLongName)
                
                ; Recursive call to handle the post-restart state
                return QB(QBversion) 
            } 
            else {
                ; Standard Finish
                qbEl.FindElement({Name:"Close", Type:"Pane"}).Click("left")
                WinClose("QuickBooks")
                return QBWaitClose(QBversion, QBLongName)
            }
        }
        
        ; Case C: Stuck/Cancelled - Retry
        else if (InStr(currentText, "Updates Cancelled")) {
            qbEl.WaitElement({Name:"Get Updates", Type:"Pane"}).Click("left")
        }

        ; Case D: Freeze Detection (Every ~30 seconds)
        if (Mod(A_Index, 30) == 0) {
            if (currentText == previousLine && currentText != "") {
                ; Stuck on same text? Try stopping.
                try qbEl.FindElement({Name:"Stop Updates", Type:"Pane"}).Click("left")
            } else {
                previousLine := currentText
            }
        }
    }
}

; ==============================================================================
; Helper Functions
; ==============================================================================

HandleIEPopup() {
    if WinExist("Upgrade Internet Explorer") {
        try WinActivate("Upgrade Internet Explorer")
        try ControlClick("OK", "Upgrade Internet Explorer")
        try Send("{Enter}")
    }
}

KillQBTasks() {
    UpdateStatus("Killing open QB tasks...", 100, 100)
    
    try {
        wmi := ComObjGet("winmgmts:")
        processes := wmi.ExecQuery("Select * from Win32_Process Where Name LIKE 'QB%'")
        
        for process in processes {
            RunWait("taskkill /F /PID " . process.ProcessId,, "Hide")
        }
    }
    Sleep(2500)
    UpdateStatus()
}

QBWaitClose(QBversion, QBLongName) {
    WaitCounter := 0
    Loop {
        if !ProcessExist("QBW.exe") && !ProcessExist("QBW32.exe") ; Check both 32/64 bit names
            break
            
        WaitCounter++
        UpdateStatus("Waiting for QBW process to close. Seconds: " . WaitCounter, 100, 100)
        Sleep(1000)
    }
    Sleep(1500)
    UpdateStatus()

    ; Verify Update Log
    logPath := "C:\ProgramData\Intuit\" . QBLongName . "\Components\QBUpdate\Log\Install.log"
    todayDateStr := FormatTime(, "yyMMdd") ; Use current date
    
    if FileExist(logPath) {
        logTime := FileGetTime(logPath, "M")
        logDateStr := FormatTime(logTime, "yyMMdd")
        
        if (todayDateStr == logDateStr)
            return " - Updates installed"
    }
    
    return " - No updates"
}

QBCreateINI(INIPath) {
    if FileExist(INIPath)
        FileDelete(INIPath)
        
    INIDirectory := RegExReplace(INIPath, "\\[^\\]+$") ; Get directory by stripping filename
    
    if !DirExist(INIDirectory)
        DirCreate(INIDirectory)
        
    ; Clean ini content
    iniContent := "[MRUFILES_STANDARD_STRATUM]`r`n"
                . "FILE1=C:\Hide_The_Welcome_Screen.qbw`r`n"
                . "[MRUFILES_BEL_STRATUM]`r`n"
                . "FILE1=C:\Hide_The_Welcome_Screen.qbw`r`n"
                
    FileAppend(iniContent, INIPath)
}