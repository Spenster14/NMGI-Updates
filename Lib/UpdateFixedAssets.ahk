FixedAssets(PostUpdate:=0)
{
	found:=""
	Run "C:\WinCSI\DSW\dsw.exe"
	WinWait "Sign In | Firm ID"
	WinActivate
	UIA.ElementFromHandle("Sign In | Firm ID").WaitElement({AutomationId:"SignInButton"}).Click()
	if WinWait("Onvio",,10)								;  10 second test to see if we're already logged in
	{
		; do nothing
	}
	else
	{
		WinWait "Sign in to"
		WinActivate
		UIA.ElementFromHandle("Sign in to CS Professional Suite").WaitElement({Name:"Email", Type:"Edit"}).Value :=	InputBox("Please enter the user name.","User Name").Value
		WinActivate "Sign in to"
		UIA.ElementFromHandle("Sign in to CS Professional Suite").WaitElement({Name:"Sign in", Type:"Button"}).Click()
		UIA.ElementFromHandle("Sign in to CS Professional Suite").WaitElement({Name:"Password", Type:"Edit"}).Value :=	InputBox("Please enter the user password.","User password", "password").Value
		WinActivate "Sign in to"
		UIA.ElementFromHandle("Sign in to CS Professional Suite").FindElement({Name:"Sign in", Type:"Button"}).Click()
		UIA.ElementFromHandle("Sign in to CS Professional Suite").WaitElement({Name:"Enter your one-time code", Type:"Edit"}).Value :=	InputBox("Please enter the one-time code.","One-time code").Value
		WinActivate "Enter your one"
		UIA.ElementFromHandle("Enter your one").FindElement({Name:"Continue", Type:"Button"}).Click()
		Sleep 2000
	}
	if PostUpdate
	{
		WinWaitActive "User Bulletin"
		UIA.ElementFromHandle("User Bulletin").FindElement({Name:"Close", Type:"Button"}).Click()
	}
	WinWaitActive "Fixed Assets CS"
	WinClose "Onvio"
	;~ Sleep 30000														;  Don't love this.  Need to find quicker solution. Program slow to load
	; WinMinimize "Fixed Assets CS"
	; WinMaximize "Fixed Assets CS"
	while !(WinGetMinMax("Fixed Assets CS")=="1")
	{
		Sleep 250
	}
	WinActivate "Fixed Assets CS"
	Sleep 5000
	UIA.ElementFromHandle("Fixed Assets CS").WaitElement({Name:"CS Connect", Type:"Button"}).Click()
	WinWait "CS Connect"
	UIA.ElementFromHandle("CS Connect").WaitElement({Name:"Connect", Type:"Button"}).Click()
	WinWait "Call Summary"
	if (InStr(UIA.ElementFromHandle("Call Summary").WaitElement({Type:"Document"}).Value, "No new updates", false) && PostUpdate)
	{
		return
	}
	if InStr(UIA.ElementFromHandle("Call Summary").WaitElement({Type:"Document"}).Value, "No new updates", false)
	{
		UIA.ElementFromHandle("Call Summary").FindElement({Name:"Close", Type:"Button"}).Highlight().Click()
		WinClose "Fixed Assets CS"
		FileAppend("- Fixed Assets - Updates installed`r`n",TodayDate . "-Update.log")
		return
	}
	else
	{
		MsgBox "Not no new updates, something else"							;  Need logic here for when there are updates
		;~ FileCabinet("22", "Again")												; Run a second time to clear popup
		FileAppend("- Fixed Assets - Updates installed`r`n",TodayDate . "-Update.log")
		return
	}
}