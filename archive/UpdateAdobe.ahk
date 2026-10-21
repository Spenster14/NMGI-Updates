Adobe(*)
{
	if (StrLower(GetDomainName()) == "greenwoodcpa.com")
	{
		Run "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
		WinWaitActive "Adobe"
		AcrobatEl := UIA.ElementFromHandle("Adobe Acrobat Pro (64-bit) ahk_exe Acrobat.exe")
		AcrobatEl.ElementFromPath({T:33}, {T:33,CN:"AVL_AVView", i:3}).ControlClick()
		Send "lc"
		WinWaitActive "Adobe Acrobat Updater"
		WinWaitClose "Adobe Acrobat Updater"
		WinWaitActive "Adobe Acrobat Updater"
	}
	else
	{
		Run "C:\Program Files (x86)\Adobe\Acrobat 2020\Acrobat\Acrobat.exe"
		WinWaitActive "Adobe"
		acrobatEl := UIA.ElementFromHandle("ahk_exe Acrobat.exe")
		acrobatEl.FindElement({Name:"Help", Type:"MenuItem", Order:"LastToFirstOrder"}).Click()
		acrobatEl.WaitElement({Name:"Check for Updates...", Type:"MenuItem", Order:"LastToFirstOrder"}).Click()

		WinWaitActive "Adobe Acrobat 2020 Updater"
		WinWaitClose "Adobe Acrobat 2020 Updater"
		WinWaitActive "Adobe Acrobat 2020 Updater"
	}
	;  Both should use this
	acrobatupdateEl := UIA.ElementFromHandle("ahk_exe AdobeARM.exe")
	acrobatupdateEl.WaitElement({Name:"Close", Type:"Button", mm:2}).WalkTree("-2")
	Loop {
		; **** Messaging for no update ****
		;  Missing messaging for updates
		if InStr(acrobatupdateEl.FindElement({Name:"Close", Type:"Button", mm:2}).WalkTree("-2").Name, "No updates available", false)
		{
			acrobatupdateEl.FindElement({Name:"Close", Type:"Button", mm:2}).WalkTree("-2").Highlight()
			WinClose "Updater"
			Winclose "Adobe"
			FileAppend("- Adobe Acrobat - No updates`r`n",TodayDate . "-Update.log")
			return
		}
		if InStr(acrobatupdateEl.FindElement({Name:"Close", Type:"Button", mm:2}).WalkTree("-2").Name, "Stuff has been updated!", false)
		{
			WinClose "Updater"
			Winclose "Adobe"
			FileAppend("- Adobe Acrobat - Updates installed`r`n",TodayDate . "-Update.log")
			return
		}
		Sleep 250
	}
}