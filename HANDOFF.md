# Handoff

## Session: 2026-10-21 - Milestone 4 (Module Expansion: UpdatePractice.ahk)

### Modified
- **Step 4.2**:
  - Implemented `Lib/UpdatePractice.ahk`:
    - Multi-path network and local discovery via `SafeFileExist` (`W:\`, `X:\`, `P:\`, `S:\`, UNC shares, local Program Files).
    - Authentication flow using `TRLogin()` for initial staff sign-in and waiting for user database password entry (`WinWait("Practice CS -")`).
    - Handled startup bulletins and modals via `HandleBulletins()`.
    - Navigated CS Connect, triggered "Call Now", read Call Summary text, and deferred installation by clicking "No" on "Apply Updates" prompt to prevent disruptive firm-wide database locks.
    - Returned standardized `" - Updates available (Manual)"` or `" - No updates"`.
  - Registered `PracticeCS` in `Core/AppRegistry.ahk` (`Apps` array).
  - Updated `GetAppCategory(appName)` in `Core/AppRegistry.ahk` to sort interactive database-login apps (`Accounting CS` & `Practice CS`) into Category 1 at the beginning of the queue.
  - Added `#Include <UpdatePractice>` in `NMGIUpdates.ahk`.
  - Updated `PROJECT_SPEC.md` active modules list and directory layout.

- **Step 4.2b**:
  - Added `\\sql1` network paths (`\\sql1\WinCSI`, `\\sql1\WINCSI$`, `\\sql1\Creative Solutions`, and root share) for both `PracticeCS.exe` and `practice.exe` in `Lib/UpdatePractice.ahk`.

- **Step 4.2c**:
  - Identified production executable as `CreativeSolutions.Practice.exe`.
  - Prioritized `\\sql1\winCSI\Practice CS\CreativeSolutions.Practice.exe` and `T:\Practice CS\CreativeSolutions.Practice.exe` at the top of `potentialPaths` in `Lib/UpdatePractice.ahk`.
  - Added `CreativeSolutions.Practice.exe` across all mapped drive letters (`T:`, `W:`, `X:`, `P:`, `S:`), UNC shares (`\\sql1`, `\\wbsql1`, `\\tho1`, `\\agcfsapp1`), and local paths while retaining legacy binary fallbacks.

- **Step 4.2d**:
  - Fixed infinite wait in CS Connect: added explicit 3000ms timeouts to `WaitElement`, matching both "Call Now" and "Connect" with keyboard Enter fallback.
  - Fixed infinite wait reading Call Summary: added 3000ms timeout for Document, followed by Edit, Text, and native `WinGetText` fallbacks.
  - Implemented multi-tiered button dismissal (UIA -> ControlClick -> Keyboard Enter/Space -> WinClose) for both `Call Summary` and the underlying `Online Status` window, ensuring Practice CS is never blocked by modal dialogs.

- **Step 4.2e**:
  - Fixed false-positive update reporting: replaced individual element property reads with `callSumEl.DumpAll()` and `WinGetText("Call Summary")` combined text search, reliably catching `"No new updates are available"`.
  - Gated `" - Updates available (Manual)"` strictly on the vendor's `"Apply Updates"` confirmation dialog (which only pops up when updates were actually downloaded and pending application), defaulting to `" - No updates"` if absent.

- **Step 4.2f** (re-done after rollback to `7410370`):
  - Root cause of the freeze: `btn.Click()` on the "CS Connect" toolbar button = UIA `InvokePattern.Invoke()`, a synchronous cross-process call. The button opens a MODAL dialog, so the app doesn't answer until the dialog closes; Jacro's single thread blocks until UIA's `TransactionTimeout` (20 s default, measured; hit twice => ~40 s). Status stays on "Waiting for ... Connect button..." and the cursor shows busy.
  - Added `Core/CSConnect.ahk` (included from `NMGIUpdates.ahk`), used by both `Lib/UpdatePractice.ahk` and `Lib/UpdateAccountingCS.ahk`:
    - `InvokeNoFreeze(btn)`: temporarily lowers `UIA.TransactionTimeout` to 1.5 s around the one blocking Invoke, then restores it.
    - `WaitForCSConnect(exe)` / `FindCSConnectHwnd(exe)`: yielding `Sleep(100)` poll; matches `CS Connect ahk_exe <process of the main window>` (TitleMatchMode 2; DetectHiddenWindows fallback, both restored).
    - `ClickCallNow(hwnd)`: A) exact-text control match ("Call Now", `&` stripped) -> `ControlClick`, then posted `BM_CLICK`; B) `WinActivate` + `{Enter}` then `!n`; C) client-relative coordinate click (~74.5% / 92%).
    - `DescribeControls(hwnd)` + `CSConnectLog()`: HWND, exe, control list and winning tier written to `CSConnect-debug.log` next to the script/exe; HWND also shown in the status box.
  - Both modules now return `" - Error (CS Connect window not found)"` if the dialog never appears, instead of waiting up to 300 s for Call Summary.
  - Note: the earlier substring match ("Call"/"Now") would also match the "Connect now" radio; matching is now exact.

### Tested
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly.
- Mock "CS Connect" dialog (radio "Connect now", "&Call Now", Cancel): HWND/exe detection correct; tier A clicked only Call Now; tier C (relative click) also works. Tier B (keystrokes) could not be validated in the headless session.
- Confirmed `UIA.TransactionTimeout` default 20000 ms and read/write works.
- NOT yet verified against live Practice CS / Accounting CS (cannot reproduce the modal-blocking provider here).
- Validated category ordering logic: Category 1 items (`Accounting CS`, `Practice CS`) run first upfront, followed by automated TR apps (Category 2), QuickBooks (Category 3), Lacerte/Adobe (Category 4), and Browsers (Category 5).

### Unfinished Logic / Known Quirks Documented
- Live CS Connect call and "Apply Updates" dismissal requires validation on an operator workstation with Thomson Reuters Practice CS installed.
- The toolbar Invoke may still hold Jacro's thread for up to ~1.5 s (the bound). If that is unacceptable, next option is posting `WM_LBUTTONDOWN/UP` to the ToolbarWindow32 (needs TB_GETITEMRECT via remote memory).
- If it still stalls, send `CSConnect-debug.log` (shows Invoke elapsed ms, HWND, control list, tier used).
- Do not spawn helper scripts/processes via `A_AhkPath`/`A_ScriptDir` from the compiled `NMGIupdates.exe`: for compiled scripts this relaunches Jacro itself and `#SingleInstance force` kills the running instance (the "Could not close the previous instance" prompt).
- Commented-out `#Include <UpdateFPS>` in `NMGIUpdates.ahk` remains in `archive/` awaiting future modernization.

### Next Step / Status
- Operator to run Practice CS (and Accounting CS) on a test machine and report timing/behaviour; attach `CSConnect-debug.log` if anything fails.





