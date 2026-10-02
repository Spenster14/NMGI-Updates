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
        ExitApp
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
        ExitApp
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
        return " - Error"
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
        return " - Error"
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
        return " - Error"
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


/* QB(QBversion)
{
	foundupdate:=""
	previousline:=""
	KillQBTasks()

	;  Set variables
	switch QBversion
	{
		case "21 Enterprise":
			QBLongName := "QuickBooks Enterprise Solutions 21.0"
			QBExe := "QBW32EnterpriseAccountant.exe"
		case "22 Enterprise":
			QBLongName := "QuickBooks Enterprise Solutions 22.0"
			QBExe := "QBWEnterpriseAccountant.exe"
		case "23 Enterprise":
			QBLongName := "QuickBooks Enterprise Solutions 23.0"
			QBExe := "QBWEnterpriseAccountant.exe"
		case "24 Enterprise":
			QBLongName := "QuickBooks Enterprise Solutions 24.0"
			QBExe := "QBWEnterpriseAccountant.exe"
		case "21 Premier":
			QBLongName := "QuickBooks 2021"
			QBExe := "QBW32Pro.exe"
		case "22 Premier":
			QBLongName := "QuickBooks 2022"
			QBExe := "QBWPremierAccountant.exe"
		case "23 Premier":
			QBLongName := "QuickBooks 2023"
			QBExe := "QBWPremierAccountant.exe"
		case "24 Premier":
			QBLongName := "QuickBooks 2024"
			QBExe := "QBWPremierAccountant.exe"
		case "23 Pro":
			QBLongName := "QuickBooks 2023"
			QBExe := "QBWPro.exe"
		case "24 Pro":
			QBLongName := "QuickBooks 2024"
			QBExe := "QBWPro.exe"
	}

	;  Create generic INI
	QBCreateINI(EnvGet("LocalAppData") . "\Intuit\" . QBLongName . "\QBWUSER.INI")

	; Opening QB version
	UpdateStatus("Waiting for Quickbooks to open.", 100, 100)
	if FileExist("C:\Program Files\Intuit\" . QBLongName . "\" . QBExe)
		Run "C:\Program Files\Intuit\" . QBLongName . "\" . QBExe
	else if FileExist("C:\Program Files (x86)\Intuit\" . QBLongName . "\" . QBExe)
		Run "C:\Program Files (x86)\Intuit\" . QBLongName . "\" . QBExe
	else {
		MsgBox("Could not find the install location.  Please let Jon Y know and do this one manually for now.")
		ExitApp
	}

	WinWait("QuickBooks ")
	ToolTip
	if WinExist("QuickBooks ","Install "){                     ;  Handling major upgrade
		WinActivate
		qbEl := UIA.ElementFromHandle("QuickBooks")
		qbEl.WaitElement({Name:"Install Now", Type:"Pane"}).Click("left")
		WinWait("QuickBooks","restart your computer")
		; FileAppend("- QuickBooks " . QBversion . " - Updates installed`r`n",TodayDate . "-Update.log")
		qbEl := UIA.ElementFromHandle("QuickBooks")
		qbEl.WaitElement({Name:"Yes", Type:"Button"}).Click("left")  ;  Rebooting at the end
		return " - Updates installed"
	}
	WinWait("QuickBooks ",,,"Service")
	Sleep 2000
	WinActivate
	WinMaximize
	qbEl := UIA.ElementFromHandle("QuickBooks")
	Send "!hd"
	qbEl.WaitElement({Name:"Update Now", Type:"Pane"}).Click("left")
	qbEl.WaitElement({Name:"Get Updates", Type:"Pane"}).Click("left")
	Sleep 2000
	qbElLoc := qbEl.WaitElement({Name:"Update QuickBooks Desktop", Type:"Window"}).Location
	qbElLoc.h := (qbElLoc.h / 3)
	qbElLoc.y := (QbElLoc.y + (qbElLoc.h * 2))    ; Multiply by 1 less than divided by above... ex 5 above, 4 here.
	qbElLoc.w := (qbElLoc.w * 0.6)                 ;  Left 60% of the rectangle
	Loop {
		Sleep 250																; Sleep 0.25 seconds
		result := OCR.FromRect(qbElLoc.x, qbElLoc.y, qbElLoc.w, qbElLoc.h,,2)
		UpdateStatus("Currently sees: " . result.Text . " Previous: " . previousline, 100, 100)
		if (InStr(result.Text, "%", false) && !foundupdate)									; Flag for us seeing an update being installed
			foundupdate:=1
		else if (InStr(result.Text, "Update Complete", false))
		{
			Sleep 500
			if WinExist("QuickBooks Desktop Information") {      ;  Restart required               ; Kill the popup
				WinActivate("QuickBooks Desktop Information")
				Send "{Space}"
				WinWait("QuickBooks ",,,"Service")
				WinActivate("QuickBooks ",,,"Service")
				foundupdate:=1
				qbEl.FindElement({Name:"Close", Type:"Pane"}).Click("left")
				WinClose "QuickBooks"
				QBWaitClose(QBversion, QBLongName)
				return QB(QBversion)
			}
			else
			{
				result.Highlight(result)
				qbEl.FindElement({Name:"Close", Type:"Pane"}).Click("left")
				WinClose "QuickBooks"
				return QBWaitClose(QBversion, QBLongName)
			}
		}
		else if InStr(result.Text, "Updates Cancelled", false)					; Recovering from stuck updates, press get updates button
			qbEl.WaitElement({Name:"Get Updates", Type:"Pane"}).Click("left")

		if (Mod(A_Index, 120) == 0)												;  Every 30 seconds, see if the line we check has changed
		{
			if (result.Text == previousline)
			{
				qbEl.FindElement({Name:"Stop Updates", Type:"Pane"}).Click("left")
			}
			else
				previousline := result.Text
		}
	}
}

;  Make sure no QB processes are running at all
KillQBTasks() {
	UpdateStatus("Killing open QB tasks...", 100, 100)
	for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process")
		{
			if (InStr(process.Name,"QB") == 1)
				RunWait("taskkill /f /im " . process.Name)
		}
	Sleep(2500)
}


QBWaitClose(QBversion, QBLongName){
	WaitCounter := 0
	loop
	{
		if !ProcessExist("QBW.exe")
			break
		WaitCounter += 1
		UpdateStatus("Waiting for QBW.exe process to close. Seconds: " . WaitCounter, 100, 100)
		Sleep(1000)
	}
	Sleep(1500)
	ToolTip

	if (TodayDate == (FormatTime(FileGetTime("C:\ProgramData\Intuit\" . QBLongName . "\Components\QBUpdate\Log\Install.log", "M"), "yyMMdd")))
		return " - Updates installed"
	else
		return " - No updates"

	;"C:\Program Files (x86)\Intuit\" . QBLongName . "\" . QBExe
	;FileAppend("- QuickBooks " . QBversion . " - Updates installed`r`n",TodayDate . "-Update.log")

}

QBCreateINI(INIPath){
	if FileExist(INIPath){
		FileDelete(INIPath)   ;  Delete current INI file
	}
	INIDirectory := SubStr(INIPath, 1, StrLen(INIPath)-12)
	If !DirExist(INIDirectory)
		DirCreate(INIDirectory)
	FileAppend("[MRUFILES_STANDARD_STRATUM]`r`nFILE1=C:\Hide_The_Welcome_Screen.qbw`r`n[MRUFILES_BEL_STRATUM]`r`nFILE1=C:\Hide_The_Welcome_Screen.qbw`r`n", INIPath)  ; Recreated with just the lines I want
} */