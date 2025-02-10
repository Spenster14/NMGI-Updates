QB(QBversion)
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
			QBExe := "QBW32PremierAccountant.exe"
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
			; Need to find ini location
		case "24 Pro":
			; Need to find ini location
	}

	;  Create generic INI
	QBCreateINI(EnvGet("LocalAppData") . "\Intuit\" . QBLongName . "\QBWUSER.INI")

	; Opening QB version
	ToolTip("Waiting for Quickbooks to open.", 100, 100)
	if FileExist("C:\Program Files\Intuit\" . QBLongName . "\" . QBExe)
		Run "C:\Program Files\Intuit\" . QBLongName . "\" . QBExe
	else if FileExist("C:\Program Files (x86)\Intuit\" . QBLongName . "\" . QBExe)
		Run "C:\Program Files (x86)\Intuit\" . QBLongName . "\" . QBExe

	WinWait("QuickBooks ")
	ToolTip
	if WinExist("QuickBooks ","Install "){                     ;  Handling major upgrade
		WinActivate
		qbEl := UIA.ElementFromHandle("QuickBooks")
		qbEl.WaitElement({Name:"Install Now", Type:"Pane"}).Click("left")
		WinWait("QuickBooks","restart your computer")
		FileAppend("- QuickBooks " . QBversion . " - Updates installed`r`n",TodayDate . "-Update.log")
		qbEl := UIA.ElementFromHandle("QuickBooks")
		qbEl.WaitElement({Name:"Yes", Type:"Button"}).Click("left")  ;  Rebooting at the end
		return
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
		ToolTip("Currently sees: " . result.Text . " Previous: " . previousline, 100, 100)
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
				QB(QBversion)
				return
			}
			else
			{
				result.Highlight(result)
				qbEl.FindElement({Name:"Close", Type:"Pane"}).Click("left")
				WinClose "QuickBooks"
				QBWaitClose(QBversion, QBLongName)
				return
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
	for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process")
		{
			if (InStr(process.Name,"QB") == 1)
				RunWait("taskkill /f /im " . process.Name)
		}
	Sleep(2000)
}


QBWaitClose(QBversion, QBLongName){
	;  *** Sneak in cleaning up our update output
	RemoveOutput(QBversion)
	;  Update log
	if (TodayDate == (FormatTime(FileGetTime("C:\ProgramData\Intuit\" . QBLongName . "\Components\QBUpdate\Log\Install.log", "M"), "yyMMdd")))
		FileAppend("- QuickBooks " . QBversion . " - Updates installed`r`n",TodayDate . "-Update.log")
	else
		FileAppend("- QuickBooks " . QBversion . " - No updates`r`n",TodayDate . "-Update.log")

	;"C:\Program Files (x86)\Intuit\" . QBLongName . "\" . QBExe
	;FileAppend("- QuickBooks " . QBversion . " - Updates installed`r`n",TodayDate . "-Update.log")
	WaitCounter := 0
	loop
	{
		if !ProcessExist("QBW.exe")
			break
		WaitCounter += 1
		ToolTip("Waiting for QBW.exe process to close. Seconds: " . WaitCounter, 100, 100)
		Sleep(1000)
	}
	ToolTip
}

QBCreateINI(INIPath){
	if FileExist(INIPath){
		FileDelete(INIPath)   ;  Delete current INI file
	}
	FileAppend("[MRUFILES_STANDARD_STRATUM]`r`nFILE1=C:\Hide_The_Welcome_Screen.qbw`r`n[MRUFILES_BEL_STRATUM]`r`nFILE1=C:\Hide_The_Welcome_Screen.qbw`r`n", INIPath)  ; Recreated with just the lines I want
}