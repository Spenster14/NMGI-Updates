Chrome(*)
{
	if (StrLower(GetDomainName()) == "greenwoodcpa.com")
		Run "C:\Program Files\Google\Chrome\Application\chrome.exe"
	else
		Run "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
	WinWaitActive "Chrome"
	WinMaximize "Chrome"
	while !(WinGetMinMax("Chrome")=="1")
	{
		Sleep 250
		WinMaximize "Chrome"
	}
	Sleep 1000
	chromeEl := UIA.ElementFromHandle("ahk_exe chrome.exe")
	chromeEl.WaitElement({Name:"Chrome", Type:"MenuItem", Order:"LastToFirstOrder"}).Click()
	chromeEl.WaitElement({Name:"Help", Type:"MenuItem", Order:"LastToFirstOrder"}).Click()
	chromeEl.WaitElement({Name:"About Google Chrome", Type:"MenuItem", Order:"LastToFirstOrder"}).Click()
	Sleep 1000
	Loop {
		result := OCR.FromWindow("Chrome",,2)
		Loop result.Lines.Length{
			if InStr(result.Lines[A_Index].Text, "Version", false)
			StatusLine := A_Index - 1
		}
		try resultline := result.Lines[StatusLine].Text
		catch
		{
			continue
		}
		if InStr(result.Text, "Chrome is up to", false)
		{
            Loop result.Lines.Length{
                if InStr(result.Lines[A_Index].Text, "Chrome is up to", false)
                    result.Highlight(result.Lines[A_Index])
            }
			WinClose "Chrome"
			return "Chrome - No Updates`n"
		}
		else if InStr(result.Text, "Relaunch Chrome", false)
		{
            Loop result.Lines.Length{
                if InStr(result.Lines[A_Index].Text, "Relaunch Chrome", false)
                    result.Highlight(result.Lines[A_Index])
            }
			WinClose "Chrome"
			Sleep 2000
			Chrome()
			return "Chrome - Updates installed`n"
		}
		Sleep 100
	}
}