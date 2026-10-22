#Requires AutoHotkey v2.0
; Core/Process.ahk - Unified process termination and cleanup routines.

TerminateProcessGracefully(exeName, waitSeconds := 3, forceKillAfterTimeout := true) {
    if !ProcessExist(exeName)
        return true

    ; Attempt gentle close via window message first
    try {
        if WinExist("ahk_exe " . exeName)
            WinClose("ahk_exe " . exeName)
    }

    ; Wait for process to exit cleanly
    closed := ProcessWaitClose(exeName, waitSeconds)

    ; Force kill if still lingering and requested
    if (!closed && forceKillAfterTimeout && ProcessExist(exeName)) {
        try {
            RunWait("taskkill /F /IM " . exeName . " /T", , "Hide")
        }
        ProcessWaitClose(exeName, 2)
    }

    return !ProcessExist(exeName)
}

KillProcessesByPrefix(prefix) {
    try {
        wmi := ComObjGet("winmgmts:")
        processes := wmi.ExecQuery("Select * from Win32_Process Where Name LIKE '" . prefix . "%'")
        for process in processes {
            try RunWait("taskkill /F /PID " . process.ProcessId, , "Hide")
        }
    }
}

; Launch a process as standard user (medium integrity) from an elevated process via Windows Shell
ShellRun(filePath, arguments := "", directory := "", operation := "", show := 1) {
    static VT_UI4 := 0x13, SWC_DESKTOP := ComValue(VT_UI4, 0x8)
    ComObject("Shell.Application").Windows.Item(SWC_DESKTOP).Document.Application
        .ShellExecute(filePath, arguments, directory, operation, show)
}

