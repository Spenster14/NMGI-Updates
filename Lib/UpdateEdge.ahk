Edge(*)
{
	Run "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
	WinWaitActive "Edge"
	WinMaximize "Edge"
	while !(WinGetMinMax("Edge")=="1")
	{
		Sleep 250
		WinMaximize "Edge"
	}
	Sleep 1000
	edgeEl := UIA.ElementFromHandle("ahk_exe msedge.exe")
	edgeEl.WaitElement({Name:"(Alt+F)", Type:"Button", mm:2}).ControlClick()
	edgeEl.WaitElement({Name:"Help and feedback", Type:"MenuItem"}).Click()
	edgeEl.WaitElement({Name:"About Microsoft Edge", Type:"MenuItem"}).Click()
	Sleep 1000
	Loop {
		result := OCR.FromWindow("Edge",,2)
		Loop result.Lines.Length{
			if InStr(result.Lines[A_Index].Text, "64-bit", false)
			StatusLine := A_Index + 1
		}
		try resultline := result.Lines[StatusLine].Text
		catch
		{
			continue
		}
		if InStr(resultline, "Edge is up", false)
		{
			HighlightResult := result.Lines[StatusLine]
			result.Highlight(result.Lines[StatusLine])
			WinClose "Edge"
			return "Edge - No Updates`n"
		}
		else if InStr(resultline, "To finish updating", false)
		{
			WinClose "Edge"
			Sleep 2000
			Edge()
			return "Edge - Updates installed`n"
		}
		Sleep 100
	}



	;~ ;************  Need to update this information for Edge  *******************************

	;~ edgeEl.WaitElement({Name:"About", LocalizedType:"heading", Type:"Text", mm:2}).WalkTree("P, 4, 1")
	;~ Loop {
		;~ if InStr(edgeEl.FindElement({Name:"About", LocalizedType:"heading", Type:"Text", mm:2}).WalkTree("P, 4, 1").Name, "Microsoft Edge is up to date", false)
		;~ {
			;~ edgeEl.FindElement({Name:"About", LocalizedType:"heading", Type:"Text", mm:2}).WalkTree("P, 4, 1").Highlight()
			;~ WinClose "Edge"
			;~ return "Edge - No Updates`n"
		;~ }
		;~ else if InStr(edgeEl.FindElement({Name:"About", LocalizedType:"heading", Type:"Text", mm:2}).WalkTree("P, 4, 1").Name, "To finish updating, restart", false)  ; Message confirmed
		;~ {
			;~ WinClose "Edge"
			;~ WinWaitClose "Edge"
			;~ Sleep 2000
			;~ Edge()
			;~ return "Edge - Updates installed`n"
		;~ }
		;~ Sleep 250
	;~ }
}