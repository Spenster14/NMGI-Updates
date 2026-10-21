#Requires AutoHotkey v2.0
; Core/Logger.ahk - status lookup, status colors, and update-log engine (moved verbatim from NMGIUpdates.ahk). Reads the global TodayDate defined in the entry script.

GetAppStatus(appName) {
    global TodayDate
    logFile := TodayDate . "-Update.log"
    if !FileExist(logFile)
        return ""
    fileContent := FileRead(logFile)
    loop parse, fileContent, "`n", "`r" {
        if InStr(A_LoopField, appName) {
            if InStr(A_LoopField, " - Updates installed")
                return "Updated"
            if InStr(A_LoopField, " - No updates")
                return "NotUpdated"
            if InStr(A_LoopField, " - Error")
                return "Error"
            return "Attention" ; Some other status
        }
    }
    return ""
}

GetColorByStatus(status) {
    if (status == "Updated")
        return "c107C10" ; Deep Professional Green (Excel)
    if (status == "NotUpdated")
        return "cA0A0A0" ; Light Gray (Faded out)
    if (status == "Error" || status == "Attention")
        return "cFF0000" ; Red
    return "c000000" ; Default Black
}

UpdateLog(appName, updateresult) {
    logFile := TodayDate . "-Update.log"

    ; 1. If file doesn't exist, just create it
    if !FileExist(logFile) {
        FileAppend(appName . updateresult . "`n", logFile)
        return
    }

    ; 2. Read the entire file into memory
    fileContent := FileRead(logFile)
    newContent := ""
    found := false

    ; 3. Loop through line by line to rebuild the file
    loop parse, fileContent, "`n", "`r" {
        if (A_LoopField = "") ; Skip empty lines if needed
            continue

        if (InStr(A_LoopField, appName . " - Updates installed"))             ;  Do not update list if it already says it was updated
        {
            found := 1
            newContent .= A_LoopField . "`r`n"
            continue
        }

        if (InStr(A_LoopField, appName))   ;  If it finds the app, and the update result is now updated (should have filtered out already updated ones...) change it to updated
        {
            ; FOUND IT! Replace this line with our new data
            newContent .= appName . updateresult . "`r`n"
            found := true
        } else {
            ; Keep the old line exactly as it is
            newContent .= A_LoopField . "`r`n"
        }
    }

    ; 4. If we didn't find today's line, append it to the end
    if (!found)
        newContent .= appName . updateresult . "`r`n"

    ; 5. Delete the old file and write the new content
    try {
        FileDelete(logFile)
        FileAppend(newContent, logFile)
    } catch as err {
        MsgBox("Error updating log: " . err.Message)
    }
}
