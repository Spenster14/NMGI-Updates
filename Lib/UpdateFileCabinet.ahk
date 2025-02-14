FileCabinet(PostUpdate:=0)
{
	found:=""
	Run "C:\WinCSI\CABINET\fcab.exe"
	TRLogin()
	if PostUpdate
	{
		WinWaitActive "User Bulletin"
		UIA.ElementFromHandle("User Bulletin").FindElement({Name:"Close", Type:"Button"}).Click()
	}
	WinWaitActive "FileCabinet CS"
	WinClose "Onvio"
	;~ Sleep 30000														;  Don't love this.  Need to find quicker solution. Program slow to load
	WinMinimize "FileCabinet CS"
	WinMaximize "FileCabinet CS"
	while !(WinGetMinMax("FileCabinet CS")=="1")
	{
		Sleep 250
	}
	WinActivate "FileCabinet CS"
	Sleep 5000
	UIA.ElementFromHandle("FileCabinet CS").FindElement({Name:"CS Connect (Ctrl+K)", Type:"Button"}).Click()
	WinWait "CS Connect"
	UIA.ElementFromHandle("CS Connect").WaitElement({Name:"Call Now", Type:"Button"}).Click()
	WinWait "Call Summary"
	if (InStr(UIA.ElementFromHandle("Call Summary").FindElement({Type:"ListItem"}).Name, "No new updates", false) && PostUpdate)
	{
		return
	}
	if InStr(UIA.ElementFromHandle("Call Summary").FindElement({Type:"ListItem"}).Name, "No new updates", false)
	{
		UIA.ElementFromHandle("Call Summary").FindElement({Name:"Close", Type:"Button"}).Highlight().Click()
		WinClose "FileCabinet"
		FileAppend("- FileCabinet - No updates`r`n",TodayDate . "-Update.log")
		return
	}
	else
	{
		MsgBox "Not no new updates, something else"							;  Need logic here for when there are updates
		;~ FileCabinet("22", "Again")												; Run a second time to clear popup
		FileAppend("- FileCabinet - Updates installed`r`n",TodayDate . "-Update.log")
		return
	}
}