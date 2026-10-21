#Requires AutoHotkey v2.0
; Lib/UpdatePPC.ahk - Thomson Reuters PPC Tools & Practice Aids Installer module.
; Detects available product updates by inspecting the tree checkboxes in PPCWebMultiSelect.

GetPPCPath() {
    candidatePaths := [
        "C:\Program Files (x86)\Common Files\PPC\PPCWebMultiSelectInstaller\PPCWebMultiSelect.exe",
        "C:\Program Files\Common Files\PPC\PPCWebMultiSelectInstaller\PPCWebMultiSelect.exe",
        "C:\Common Files\PPC\PPCWebMultiSelectInstaller\PPCWebMultiSelect.exe"
    ]

    for path in candidatePaths {
        if SafeFileExist(path)
            return path
    }
    return ""
}

PPC(PostUpdate := false) {
    ; --- 0. Clean up any existing installer instance ---
    if ProcessExist("PPCWebMultiSelect.exe") {
        UpdateStatus("Closing existing PPC Installer instances...", 100, 100)
        TerminateProcessGracefully("PPCWebMultiSelect.exe", 2, true)
        UpdateStatus()
    }

    ; --- 1. Validate Installation Path ---
    ppcPath := GetPPCPath()
    if (ppcPath == "") {
        return " - Error (Path not found)"
    }

    ; --- 2. Launch PPC Installer ---
    UpdateStatus("Launching PPC Installer...", 100, 100)
    try {
        Run(ppcPath)
    } catch as err {
        UpdateStatus()
        return " - Error (Launch failed: " . err.Message . ")"
    }

    ; --- 3. Step 1: Thomson Reuters Setup - Installation Type ---
    UpdateStatus("Waiting for PPC Installation Type...", 100, 100)
    if !WinWait("Thomson Reuters Setup - Installation Type", , 30) {
        UpdateStatus()
        TerminateProcessGracefully("PPCWebMultiSelect.exe", 2, true)
        return " - Error (Installation Type timeout)"
    }

    WinActivate("Thomson Reuters Setup - Installation Type")
    WinWaitActive("Thomson Reuters Setup - Installation Type", , 5)
    Sleep(500)

    ; Advance through Installation Type screen by clicking "Next >"
    UpdateStatus("Advancing to product selection...", 100, 100)
    nextClicked := false
    try {
        typeEl := UIA.ElementFromHandle("Thomson Reuters Setup - Installation Type")
        nextBtn := typeEl.FindElement({Name: "Next >", Type: "Button", mm: 2})
        if (!nextBtn)
            nextBtn := typeEl.FindElement({Name: "Next", Type: "Button", mm: 2})
        if (nextBtn) {
            try nextBtn.Highlight(500)
            nextBtn.Click()
            nextClicked := true
        }
    }

    if (!nextClicked) {
        ; Native Win32 / Keyboard fallback
        try ControlClick("&Next >", "Thomson Reuters Setup - Installation Type")
        catch {
            WinActivate("Thomson Reuters Setup - Installation Type")
            Send("!n")
        }
    }

    ; --- 4. Step 2: Thomson Reuters Setup - Client ---
    UpdateStatus("Waiting for PPC Client selection window...", 100, 100)
    if !WinWait("Thomson Reuters Setup - Client", , 30) {
        UpdateStatus()
        TerminateProcessGracefully("PPCWebMultiSelect.exe", 2, true)
        return " - Error (Client selection timeout)"
    }

    WinActivate("Thomson Reuters Setup - Client")
    WinWaitActive("Thomson Reuters Setup - Client", , 5)
    Sleep(1000)

    ; --- 5. Inspect Tree Checkboxes for Updates ---
    UpdateStatus("Inspecting PPC product checkboxes...", 100, 100)
    hasChecked := false

    try {
        clientEl := UIA.ElementFromHandle("Thomson Reuters Setup - Client")

        ; Primary check: inspect all TreeItem and CheckBox elements in the tree
        items := clientEl.FindElements({Type: "TreeItem"})
        if (items.Length == 0)
            items := clientEl.FindElements({Type: "CheckBox"})

        for item in items {
            try {
                ; ToggleState: 0 = Off/Unchecked, 1 = On/Checked, 2 = Indeterminate
                ts := item.ToggleState
                if (ts == 1 || ts == "1" || ts == "On") {
                    hasChecked := true
                    try item.Highlight(1000)
                    break
                }
            }
            try {
                val := item.Value
                if (val == 1 || val == "1" || val == "Checked") {
                    hasChecked := true
                    try item.Highlight(1000)
                    break
                }
            }
        }

        ; Secondary fallback check: inspect DumpAll string for checked state
        if (!hasChecked) {
            dumpText := clientEl.DumpAll()
            if RegExMatch(dumpText, "i)ToggleState:\s*(1|On)")
                hasChecked := true
        }
    } catch {
        hasChecked := false
    }

    ; --- 6. Dismiss the Installer (Cancel) ---
    UpdateStatus("Closing PPC Installer...", 100, 100)
    try {
        clientEl := UIA.ElementFromHandle("Thomson Reuters Setup - Client")
        cancelBtn := clientEl.FindElement({Name: "Cancel", Type: "Button", mm: 2})
        if (cancelBtn) {
            try cancelBtn.Highlight(500)
            cancelBtn.Click()
        } else {
            Send("{Esc}")
        }
    } catch {
        Send("{Esc}")
    }

    Sleep(500)
    if WinExist("Thomson Reuters Setup - Client")
        try WinClose("Thomson Reuters Setup - Client")

    TerminateProcessGracefully("PPCWebMultiSelect.exe", 2, true)
    UpdateStatus()

    ; --- 7. Return Result ---
    if (hasChecked) {
        return " - Updates available (Manual)"
    } else {
        return " - No updates"
    }
}
