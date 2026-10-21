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
    totalCheckboxes := 0
    checkedCount := 0

    try {
        clientEl := UIA.ElementFromHandle("Thomson Reuters Setup - Client")

        ; Primary check: inspect all TreeItem and CheckBox elements in the tree
        items := clientEl.FindElements({Type: "TreeItem"})
        cbItems := clientEl.FindElements({Type: "CheckBox"})

        ; If explicit CheckBox elements exist in the tree
        if (cbItems.Length > 0) {
            totalCheckboxes := cbItems.Length
            for cb in cbItems {
                cbChecked := false
                try {
                    ts := cb.ToggleState
                    if (ts == 1 || ts == "1" || ts == "On")
                        cbChecked := true
                }
                if (!cbChecked) {
                    try {
                        val := cb.Value
                        if (val == 1 || val == "1" || val == "Checked")
                            cbChecked := true
                    }
                }
                if (cbChecked) {
                    checkedCount++
                    try cb.Highlight(500)
                }
            }
        } else if (items.Length > 0) {
            ; Check TreeItem elements directly for ToggleState or child CheckBoxes
            totalCheckboxes := items.Length
            for item in items {
                itemChecked := false
                try {
                    ts := item.ToggleState
                    if (ts == 1 || ts == "1" || ts == "On")
                        itemChecked := true
                }
                if (!itemChecked) {
                    try {
                        val := item.Value
                        if (val == 1 || val == "1" || val == "Checked")
                            itemChecked := true
                    }
                }
                if (!itemChecked) {
                    ; Check if a child element has toggle or checked state
                    try {
                        childCb := item.FindElement({Type: "CheckBox"})
                        if (childCb) {
                            cts := childCb.ToggleState
                            if (cts == 1 || cts == "1" || cts == "On")
                                itemChecked := true
                        }
                    }
                }
                if (itemChecked) {
                    checkedCount++
                    try item.Highlight(500)
                }
            }
        }

        ; Secondary fallback check: inspect DumpAll string if element search didn't find items
        if (totalCheckboxes == 0) {
            dumpText := clientEl.DumpAll()
            pos := 1
            while (pos := RegExMatch(dumpText, "i)ToggleState:\s*([0-9a-z]+)", &m, pos)) {
                totalCheckboxes++
                if (m[1] = "1" || m[1] = "On")
                    checkedCount++
                pos += StrLen(m[0])
            }
        }
    } catch {
        hasChecked := false
    }

    if (checkedCount > 0)
        hasChecked := true

    ; User test request: report number of checkboxes seen and pause for 1 second
    UpdateStatus("PPC: " . totalCheckboxes . " checkboxes seen (" . checkedCount . " checked)", 100, 100)
    Sleep(1000)

    ; --- 6. Dismiss the Installer (Cancel -> Confirmation Yes) ---
    UpdateStatus("Closing PPC Installer...", 100, 100)
    cancelClicked := false
    try {
        clientEl := UIA.ElementFromHandle("Thomson Reuters Setup - Client")
        cancelBtn := clientEl.FindElement({Name: "Cancel", Type: "Button", mm: 2})
        if (cancelBtn) {
            try cancelBtn.Highlight(500)
            cancelBtn.Click()
            cancelClicked := true
        }
    }
    if (!cancelClicked) {
        try {
            ControlClick("&Cancel", "Thomson Reuters Setup - Client")
            cancelClicked := true
        } catch {
            try {
                ControlClick("Button4", "Thomson Reuters Setup - Client")
                cancelClicked := true
            } catch {
                WinActivate("Thomson Reuters Setup - Client")
                Send("!c")
            }
        }
    }

    ; Wait for confirmation popup: "Are you sure you want to cancel the installation?"
    confirmHandled := false
    loop 30 {
        ; Check if multiple windows exist with this title (modal dialog over parent)
        hwnds := WinGetList("Thomson Reuters Setup - Client")
        hConfirm := 0
        if (hwnds.Length > 1) {
            ; The top-most window in Z-order is the modal confirmation dialog
            hConfirm := hwnds[1]
        } else if (hwnds.Length == 1) {
            txt := WinGetText(hwnds[1])
            if InStr(txt, "Are you sure")
                hConfirm := hwnds[1]
        }

        if (!hConfirm) {
            hConfirm := WinExist("Are you sure you want to cancel")
            if (!hConfirm)
                hConfirm := WinExist("ahk_class #32770", "Are you sure")
        }

        if (hConfirm) {
            WinActivate("ahk_id " . hConfirm)
            Sleep(200)

            ; Tier A: UIA Click Yes button
            try {
                confirmEl := UIA.ElementFromHandle(hConfirm)
                yesBtn := confirmEl.FindElement({Name: "Yes", Type: "Button", mm: 2})
                if (yesBtn) {
                    try yesBtn.Highlight(500)
                    yesBtn.Click()
                    confirmHandled := true
                    break
                }
            }

            ; Tier B: Win32 ControlClick
            try {
                ControlClick("&Yes", "ahk_id " . hConfirm)
                confirmHandled := true
                break
            } catch {
                try {
                    ControlClick("Button1", "ahk_id " . hConfirm)
                    confirmHandled := true
                    break
                }
            }

            ; Tier C: Keyboard Enter (Yes is default focused button) or Alt+Y
            try {
                Send("{Enter}")
                confirmHandled := true
                break
            }
        }
        Sleep(200)
    }

    ; Final fallback if window was not explicitly matched by loop
    if (!confirmHandled && WinExist("Thomson Reuters Setup - Client")) {
        try {
            activeHwnd := WinGetID("A")
            activeEl := UIA.ElementFromHandle(activeHwnd)
            yesBtn := activeEl.FindElement({Name: "Yes", Type: "Button", mm: 2})
            if (yesBtn) {
                yesBtn.Click()
                confirmHandled := true
            }
        }
        if (!confirmHandled)
            Send("{Enter}")
    }

    ; Wait for installer to finish closing
    WinWaitClose("Thomson Reuters Setup - Client", , 10)
    TerminateProcessGracefully("PPCWebMultiSelect.exe", 2, true)
    UpdateStatus()

    ; --- 7. Return Result ---
    if (hasChecked) {
        return " - Updates available (Manual)"
    } else {
        return " - No updates"
    }
}
