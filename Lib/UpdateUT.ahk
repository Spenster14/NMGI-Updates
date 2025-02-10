UT(UTversion, PostUpdate:=0)
{
	switch UTversion
	{
		case "21":
			Run "C:\WinCSI\UT21\utw21.exe"
		case "22":
			Run "C:\WinCSI\UT22\utw22.exe"
		case "23":
			Run "C:\WinCSI\UT23\utw23.exe"
		case "24":
			{
				if FileExist("C:\WinCSI\UT24\utw24.exe")
					Run "C:\WinCSI\UT24\utw24.exe"
				else
					Run "W:\UT24\utw24.exe"
			}
	}
	WinWait "Sign In | Firm ID"
	WinActivate
	UIA.ElementFromHandle("Sign In | Firm ID").WaitElement({AutomationId:"SignInButton"}).Click()
	if WinWait("Onvio",,15)								;  10 second test to see if we're already logged in
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
	WinWaitActive "UltraTax CS"
	WinMaximize
	WinClose "Onvio"

	Loop 5{
		Sleep(1000)
		if WinExist("User Bulletin")
		{
			WinActive "User Bulletin"
			UIA.ElementFromHandle("User Bulletin").FindElement({Name:"Close", Type:"Button"}).Click()
		}
	}
	UIA.ElementFromHandle("UltraTax CS").WaitElement({Name:"CS Connect (Ctrl+K)", Type:"Button"}).Click()
	WinWait "CS Connect"
	UIA.ElementFromHandle("CS Connect").WaitElement({Name:"Connect", Type:"Button"}).Click()
	WinWait "Call Summary"
	if (InStr(UIA.ElementFromHandle("Call Summary").FindElement({LocalizedType:"document", Type:"Document"}).Value, "No new updates", false) && PostUpdate)
	{
		UIA.ElementFromHandle("Call Summary").FindElement({Name:"Close", Type:"Button"}).Highlight().Click()
		WinClose "UltraTax"
		return
	}
	if InStr(UIA.ElementFromHandle("Call Summary").FindElement({LocalizedType:"document", Type:"Document"}).Value, "No new updates", false)
	{
		UIA.ElementFromHandle("Call Summary").FindElement({Name:"Close", Type:"Button"}).Highlight().Click()
		WinClose "UltraTax"
		FileAppend("- UltraTax " . UTversion . " - No updates`r`n",TodayDate . "-Update.log")
		return
	}
	else
	{
		MsgBox "Not no new updates, something else!  Exiting. Handle manually"							;  Need logic here for when there are updates
		;~ UT("22", "Again")												; Run a second time to clear popup
		FileAppend("- UltraTax " . UTversion . " - Updates installed`r`n",TodayDate . "-Update.log")
		ExitApp
		return "UltraTax" . UTversion . " - Updates installed`r`n"
	}
}