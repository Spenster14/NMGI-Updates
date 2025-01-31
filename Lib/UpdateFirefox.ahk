Firefox(*)
{
	cfirefoxupdateEl:=""
	Run "C:\Program Files\Mozilla Firefox\firefox.exe"
	WinWaitActive "Firefox"
	WinMaximize "Firefox"
	while !(WinGetMinMax("Firefox")=="1")
	{
		Sleep 250
		WinMaximize "Firefox"
	}
	Sleep 1000
	cfirefoxEl := UIA.ElementFromHandle("A")
	cfirefoxEl.WaitElement({Name:"Firefox", Type:"Button", Order:"LastToFirstOrder"}).Click()
	cfirefoxEl.WaitElement({Name:"Help", Type:"Button", Order:"LastToFirstOrder"}).Click()
	cfirefoxEl.WaitElement({Name:"About Firefox", Type:"Button", Order:"LastToFirstOrder"}).Click()
	WinWait "About Mozilla Firefox"
	WinActivate "About Mozilla Firefox"
	Sleep 1000
	Loop {
		Mousemove(50, 50, 0)
		result := OCR.FromWindow("About Mozilla Firefox",,2)
		Loop result.Lines.Length{
			if InStr(result.Lines[A_Index].Text, "64-bit", false)
			StatusLine := A_Index - 1
		}
		try resultline := result.Lines[StatusLine].Text
		catch
		{
			continue
		}
		if InStr(resultline, "Firefox is up", false)
		{
			result.Highlight(result.Lines[StatusLine])
			WinClose "Firefox"
			WinClose "Firefox"
			return "Firefox - No Updates`n"
		}
		else if InStr(resultline, "Update to", false)
		{
			;  Need logic for pushing the button here.
			result.Highlight(result.Lines[StatusLine])   ; Untested!
			resultToClick := result.FindString(result.Lines[StatusLine].Text)
			result.Click(resultToClick, "left", 1)   ; Untested!
			Sleep 1000
		}
		else if InStr(resultline, "Restart to", false)
		{
			WinClose "Firefox"
			WinClose "Firefox"
			Sleep 2000
			Firefox()
			return "Firefox - Updates installed`n"
		}
		Sleep 100
	}
	;~ Loop {
		;~ cfirefoxEl := UIA_Browser("About Mozilla Firefox")
		;~ try cfirefoxupdateEl := cfirefoxEl.FindElement({Name:"64-bit", Type:"Edit", mm:2}).WalkTree("P, -1, 1")
		;~ catch {
			;~ Sleep 100
			;~ continue
		;~ }
		;~ if InStr(cfirefoxupdateEl.Name, "Firefox is up to date", false)
		;~ {
			;~ cfirefoxupdateEl.Highlight()
			;~ WinClose "Firefox"
			;~ WinClose "Firefox"
			;~ return "Firefox - No Updates`n"
		;~ }
		;~ else if InStr(cfirefoxupdateEl.Name, "Update to", false)  ; Need correct restart msg
		;~ {
			;~ cfirefoxEl.WaitElement({Name:"Update to", Type:"Button", Order:"LastToFirstOrder"}).Click()
		;~ }
		;~ else if InStr(cfirefoxupdateEl.Name, "Restart to Update Firefox", false)  ; Need correct restart msg
		;~ {
			;~ WinClose "Firefox"
			;~ WinClose "Firefox"
			;~ Sleep 2000
			;~ Firefox()
			;~ return "Firefox - Updates installed`n"
		;~ }
		;~ Sleep 100
	;~ }
}