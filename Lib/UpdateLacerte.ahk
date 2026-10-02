#Requires AutoHotkey v2.0
#Include <UIA>
#Include <UIA_Browser>

GetLacertePath(year) {
    pathLauncher := "C:\Lacerte\" year "tax\w" year "tax-launcher.exe"
    if FileExist(pathLauncher)
        return pathLauncher
        
    path := "C:\Lacerte\" year "tax\w" year "tax.exe"
    if FileExist(path)
        return path
        
    return ""
}

Lacerte(year) {
    global TodayDate, LacerteEmail, LacertePassword

    UpdateStatus("Checking for Lacerte 20" year " updates...", 100, 100)
    logFile := TodayDate . "-Update.log"

    ; Dynamically build executable path
    lacerteExe := GetLacertePath(year)

    if (lacerteExe == "") {
        return " - Not installed"
    }

    Run(lacerteExe)

    ; Wait for the login screen
    loginTitle := "Sign In"
    if !WinWait(loginTitle, , 30) {
        MsgBox("Lacerte login screen did not appear.")
        return " - Login timeout"
    }
    WinActivate(loginTitle)
    Sleep(4000) ; Increased delay to let slow WPF rendering completely settle
    
    try {
        loginEl := UIA.ElementFromHandle(loginTitle)
        
        ; Intuit's WPF wrapper completely blocks UIA interactions like SetFocus and Click (throws 0x80131509).
        ; Solution: Hard fallback to structural keyboard navigation.
        
        ; 1 Tab focuses and highlights the email box
        Send("{Tab}")
        Sleep(200)
        SendText(LacerteEmail)
        
        ; 2 Tabs jumps from Email to Password
        Sleep(200)
        Send("{Tab 2}")
        Sleep(200)
        SendText(LacertePassword)
        
        ; Submit the form (Enter inside the password field universally submits)
        Sleep(1500) ; Pause before submitting so the user can visually confirm the password was entered
        Send("{Enter}")
        
        Sleep(4000) ; Wait for authentication to process on slower systems
        
    } catch as err {
        MsgBox("UIA Error during Lacerte login: " err.Message)
        return " - Login error"
    }
    
    ; Wait for application to fully load (Main window)
    mainTitle := "20" year " Lacerte"
    if !WinWait(mainTitle, , 120) { ; Allow up to 2 minutes for network authentication and loading
        return " - Main window timeout"
    }
    WinActivate(mainTitle)
    
    ; The Lacerte main window appears before the background calculation engine finishes loading.
    ; Menu shortcuts (Alt+T) are ignored while the engine is initializing.
    ; Solution: Dynamically wait for the status bar to confirm initialization is complete.
    try {
        mainEl := UIA.ElementFromHandle(mainTitle)
        mainEl.WaitElement({Name: "Initializing Calculation Engine Done", Type: "Text", MatchMode: "Substring"}, 120000)
    } catch {
        ; If it fails to find the status bar text after 2 minutes, just proceed and pray.
    }
    Sleep(1000) ; Tiny buffer after the engine finishes loading
    
    ; Intuit loves throwing random tutorial or feature popups (like eSignature) over the UI.
    ; These steal keyboard focus and break the Alt+T shortcut.
    ; Solution: Spam Escape a couple times to aggressively kill any active modals.
    Send("{Escape}")
    Sleep(500)
    Send("{Escape}")
    Sleep(1000)
    
    ; Check for updates
    if (year == "22" || year == "23") {
        ; Tools -> Lacerte Updates...
        Send("!t") ; Alt+T for Tools menu
        Sleep(500)
        Send("u")  ; AccessKey 'u' works flawlessly in 22 and 23
        Sleep(2000)
    } else if (year == "24") {
        ; Tools -> Lacerte Updates... -> Check for Updates
        Send("!t") ; Alt+T for Tools menu
        Sleep(500)
        Send("u")  ; AccessKey 'u' for Lacerte Updates
        Sleep(500)
        Send("c")  ; AccessKey 'c' for Check for Updates
        Sleep(2000)
    } else {
        return " - Year not supported"
    }
    
    ; ----------------------------------------------------------------
    ; Check for Updates (Logic splits by year due to UI changes)
    ; ----------------------------------------------------------------
    if (year == "22" || year == "23") {
        ; Legacy Delphi Popup (2022 & 2023)
        updateTitle := "Lacerte Updates"
        if !WinWait(updateTitle, , 30) {
            return " - Update window timeout"
        }
        WinActivate(updateTitle)
        Sleep(3000) ; Give the popup extra time to completely render
        
        ; Lacerte forms are built in Delphi. The labels are often painted directly on the canvas and invisible to WinGetText,
        ; but the buttons are standard controls. If the "Reapply Updates" button exists, it means no new updates are available.
        updateText := WinGetText(updateTitle)
        
        if InStr(updateText, "Reapply Updates") {
            WinClose(updateTitle)
            Sleep(1000)
            WinClose(mainTitle)
            FileAppend(A_Now " - Lacerte 20" year " - No updates`r`n", logFile)
            return " - No updates"
        } else {
            MsgBox("An update is available! Script is paused. Please take a screenshot of the update window and then manually apply the update.")
            return " - Updates available (Manual)"
        }
        
    } else if (year == "24") {
        ; Modern WPF Overlay (2024)
        ; Wait for the WPF popup to spawn.
        ; The main Lacerte window is built in Delphi (TfrmMain), but the new update popup is WPF (HwndWrapper).
        ; This means we can cleanly WinWait for the specific WPF class without UIA Desktop scraping.
        try {
            ; The WPF overlay has a blank title and a dynamically generated class name.
            ; Active Window polling fails if the user clicks away, and Desktop UIA scraping times out.
            ; Solution: Use RegEx class matching to grab all WPF windows and query them directly.
            foundPopup := false
            popupWin := 0
            
            prevMatchMode := SetTitleMatchMode("RegEx")
            
            Loop 30 {
                Sleep(1000)
                try {
                    ; Get an array of all WPF window handles currently on the desktop
                    hwnds := WinGetList("ahk_class ^HwndWrapper")
                    
                    for hwnd in hwnds {
                        popupEl := UIA.ElementFromHandle(hwnd)
                        ; Check if this specific WPF window is the final up-to-date box
                        ; Note: Intuit included a trailing space in the Name property ("Lacerte is up-to-date "),
                        ; so we MUST use MatchMode: "Substring" to avoid a silent exact-match failure.
                        if popupEl.ElementExist({Name: "Lacerte is up-to-date", Type: "Text", MatchMode: "Substring"}) {
                            popupWin := hwnd
                            foundPopup := true
                            break
                        }
                    }
                }
                if (foundPopup)
                    break
            }
            
            SetTitleMatchMode(prevMatchMode) ; Reset match mode to whatever it was before
            
            if (foundPopup) {
                WinActivate(popupWin)
                Sleep(1000)
                Send("{Enter}") ; Safely trigger the 'Okay' button
                Sleep(1000)
                
                WinClose(mainTitle)
                ; Ensure it actually closed, force kill if it hung (poop storm prevention)
                if !WinWaitClose(mainTitle, , 5) {
                    WinKill(mainTitle)
                }
                FileAppend(A_Now " - Lacerte 20" year " - No updates`r`n", logFile)
                return " - No updates"
            }
            
        } catch {
            ; Swallow any unexpected polling errors
        }
        
        ; If we reach here, it either timed out or the text wasn't "up-to-date"
        MsgBox("An update might be available (or the check timed out). Script is paused. Please check the screen and manually apply the update if needed.")
        return " - Updates available (Manual)"
    }
}
