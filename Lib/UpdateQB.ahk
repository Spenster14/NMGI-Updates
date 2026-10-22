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
    
    ; 1. Authoritative desktop shortcuts (C:\Users\Public\Desktop\Applications, etc.)
    year := SubStr(QBversion, 1, 2)
    isEnterprise := InStr(QBversion, "Enterprise") ? true : false
    scPath := FindShortcutPath(
        ["qbw32.exe", "QBWEnterpriseAccountant.exe", "QBWEnterprise.exe", "QBWPremierAccountant.exe", "QBWPremier.exe", "QBWPro.exe", "QBW32Enterprise.exe", "QBW32EnterpriseAccountant.exe"],
        ,
        (item) => (
            (isEnterprise ? (InStr(item.Target, "Enterprise") || InStr(item.LnkName, "Enterprise")) : (!InStr(item.Target, "Enterprise") && !InStr(item.LnkName, "Enterprise")))
            && (InStr(item.Target, "20" . year) || InStr(item.Target, " " . year . ".") || InStr(item.LnkName, "20" . year) || InStr(item.LnkName, year))
        )
    )
    if (scPath != "")
        return scPath

    ; 2. Candidate local paths
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

    ; Start monitoring for IE, subscription, and empty window popups in the background every 500ms
    SetTimer(HandleQBPopups, 500)

    ; --- Handle Startup, Installers & Popups -----------------------------------
    mainHwnd := 0
    loop 60 {
        ; Actively dismiss subscription dialog, IE warnings, or empty window warnings
        DismissQBSubscriptionPopup()
        DismissQBEmptyWindowPopup()
        if WinExist("Upgrade Internet Explorer")
            HandleIEPopup()

        ; 1. Handle Major Upgrade / Install Prompt
        if WinExist("QuickBooks ", "Install ") {
            WinActivate("QuickBooks ", "Install ")
            try {
                qbEl := UIA.ElementFromHandle("QuickBooks")
                qbEl.WaitElement({Name:"Install Now", Type:"Pane"}).Click("left")
                WinWait("QuickBooks", "restart your computer", 60)
                
                qbEl := UIA.ElementFromHandle("QuickBooks") ; Refresh handle
                qbEl.WaitElement({Name:"Yes", Type:"Button"}).Click("left") ; Reboot confirmation
                SetTimer(HandleQBPopups, 0)
                return " - Updates installed"
            } catch {
                ; Logic to handle if elements aren't found could go here
            }
        }

        ; 2. Detect Main QuickBooks Window (exclude service, subscription, installer, and empty window dialogs)
        hwndList := WinGetList("QuickBooks")
        for h in hwndList {
            try {
                title := WinGetTitle(h)
                wText := WinGetText(h)
                if (title != "" && !InStr(title, "Service") && !InStr(title, "subscription") && !InStr(title, "Install ") && !InStr(title, "Information") && !InStr(wText, "empty QuickBooks window")) {
                    mainHwnd := h
                    break 2
                }
            }
        }
        Sleep(1000)
    }

    UpdateStatus() ; Clear status

    if (!mainHwnd) {
        SetTimer(HandleQBPopups, 0)
        MsgBox("Timed out waiting for QuickBooks main window to open.")
        return " - Error (Main window timeout)"
    }

    Sleep(3000) ; Wait for QB to settle and allow background timer to finish handling any popups
    WinActivate(mainHwnd)
    WinMaximize(mainHwnd)
    
    ; Retry getting the UIA element, as QB might be unresponsive while loading
    qbEl := ""
    loop 30 {
        try {
            qbEl := UIA.ElementFromHandle(mainHwnd)
            if qbEl
                break
        } catch {
            Sleep(1000)
        }
    }
    
    if !qbEl {
        SetTimer(HandleQBPopups, 0)
        MsgBox("Timed out waiting for QuickBooks UI to become responsive.")
        return " - Error (UI Timeout)"
    }
    
    ; Give any lingering popups one last chance to be dismissed
    if WinExist("Upgrade Internet Explorer")
        Sleep(1000)
    DismissQBSubscriptionPopup()
        
    Send("!hd") ; Open Help Menu -> Update
    
    ; Navigate Update Menu
    try {
        qbEl.WaitElement({Name:"Update Now", Type:"Pane"}).Click("left")
        qbEl.WaitElement({Name:"Get Updates", Type:"Pane"}).Click("left")
    } catch as err {
        SetTimer(HandleQBPopups, 0) ; Stop timer on error
        MsgBox("Failed to navigate Update UI: " . err.Message)
        return " - Error (UI Navigation)"
    }

    SetTimer(HandleQBPopups, 0) ; Stop timer once we successfully navigated
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

HandleQBPopups() {
    HandleIEPopup()
    DismissQBSubscriptionPopup()
    DismissQBEmptyWindowPopup()
}

FindQBSubscriptionPopup() {
    for title in ["Quickbooks subscription expired", "QuickBooks subscription expired", "Quickbooks subscription expiring", "QuickBooks subscription expiring", "subscription expired", "subscription expiring", "Quickbooks subscription", "QuickBooks subscription"] {
        hwnd := WinExist(title)
        if (hwnd)
            return hwnd
    }

    if WinExist("QuickBooks", "subscription has expired")
        return WinExist("QuickBooks", "subscription has expired")
    if WinExist("QuickBooks", "lose access to Quickbooks")
        return WinExist("QuickBooks", "lose access to Quickbooks")
    if WinExist("QuickBooks", "Renew Subscription")
        return WinExist("QuickBooks", "Renew Subscription")

    return 0
}

DismissQBSubscriptionPopup() {
    subHwnd := FindQBSubscriptionPopup()
    if (!subHwnd)
        return false

    UpdateStatus("Dismissing QuickBooks subscription popup...", 100, 100)

    ; Tier 1: UIA Element Search for Button named "Close"
    try {
        subEl := UIA.ElementFromHandle(subHwnd)
        if (subEl) {
            closeBtn := subEl.FindElement({Name: "Close", Type: "Button"})
            if (!closeBtn)
                closeBtn := subEl.FindElement({Name: "Close", mm: 2})
            if (closeBtn) {
                closeBtn.Click()
                Sleep(500)
                if !WinExist(subHwnd)
                    return true
            }
        }
    }

    ; Tier 2: Win32 ControlClick by Text "Close"
    try {
        ControlClick("Close", subHwnd,,,, "NA")
        Sleep(400)
        if !WinExist(subHwnd)
            return true
    }

    ; Tier 3: Scan child controls for text matching "Close"
    try {
        for ctrl in WinGetControls(subHwnd) {
            try {
                cText := ControlGetText(ctrl, subHwnd)
                if (InStr(cText, "Close")) {
                    ControlClick(ctrl, subHwnd,,,, "NA")
                    Sleep(400)
                    if !WinExist(subHwnd)
                        return true
                }
            }
        }
    }

    ; Tier 4: Second button is standard "Close" beside "Renew Subscription"
    try {
        ControlClick("Button2", subHwnd,,,, "NA")
        Sleep(400)
        if !WinExist(subHwnd)
            return true
    }

    ; Tier 5: Keyboard Escape
    try {
        WinActivate(subHwnd)
        Send("{Esc}")
        Sleep(500)
        if !WinExist(subHwnd)
            return true
    }

    ; Tier 6: Client Coordinate Click (~62% width, ~72% height where Close is rendered)
    try {
        WinGetPos(, , &w, &h, subHwnd)
        if (w > 100 && h > 50) {
            targetX := Integer(w * 0.62)
            targetY := Integer(h * 0.72)
            ControlClick("X" . targetX . " Y" . targetY, subHwnd,,,, "NA")
            Sleep(500)
            if !WinExist(subHwnd)
                return true
        }
    }

    ; Tier 7: WinClose
    try {
        WinClose(subHwnd)
        Sleep(500)
    }

    return !WinExist(subHwnd)
}

HandleIEPopup() {
    if WinExist("Upgrade Internet Explorer") {
        try WinActivate("Upgrade Internet Explorer")
        try ControlClick("OK", "Upgrade Internet Explorer")
        try Send("{Enter}")
    }
}

DismissQBEmptyWindowPopup() {
    hwndList := []
    try hwndList := WinGetList("QuickBooks")
    for h in hwndList {
        try {
            txt := WinGetText(h)
            if (InStr(txt, "empty QuickBooks window already exists") || InStr(txt, "use that window")) {
                UpdateStatus("Dismissing QuickBooks empty window popup...", 100, 100)
                WinActivate(h)
                Sleep(100)
                try ControlClick("OK", h,,,, "NA")
                try ControlClick("Button1", h,,,, "NA")
                Send("{Enter}")
                Sleep(400)
                if !WinExist(h)
                    return true
                try WinClose(h)
                return true
            }
        }
    }
    return false
}

KillQBTasks() {
    UpdateStatus("Killing open QB tasks...", 100, 100)
    KillProcessesByPrefix("QB")
    for proc in ["QBW32.exe", "QBW.exe", "QBWEnterprise.exe", "QBWEnterpriseAccountant.exe", "QBWPremier.exe", "QBWPro.exe"] {
        TerminateProcessGracefully(proc, 2, true)
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