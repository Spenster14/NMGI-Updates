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
    - `DescribeControls(hwnd)` + `CSConnectLog()`: Diagnostic logging used during verification; removed once `Tier A: ControlClick` was confirmed working.
  - Both modules now return `" - Error (CS Connect window not found)"` if the dialog never appears, instead of waiting up to 300 s for Call Summary.
  - Note: the earlier substring match ("Call"/"Now") would also match the "Connect now" radio; matching is now exact.

### Tested
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly.
- Live verification confirmed by operator on live Practice CS workstation (`CSConnect-debug.log`):
  - `Toolbar Invoke returned after 3031 ms (bound 1500 ms)` - blocking call bounded, no thread freeze or spinning cursor.
  - `Tier A: Call Now control = WindowsForms10.BUTTON.app.* [hwnd]` detected `Call N&ow`.
  - `Practice: Call Now result = A:ControlClick` immediately triggered and dismissed dialog in <50ms.
- Confirmed `UIA.TransactionTimeout` bounding completely eliminates the prior 40-second freeze.
- Tier B updated to include `!o` accelerator fallback in addition to `{Enter}` and `!n`.
- Validated category ordering logic: Category 1 items (`Accounting CS`, `Practice CS`) run first upfront, followed by automated TR apps (Category 2), QuickBooks (Category 3), Lacerte/Adobe (Category 4), and Browsers (Category 5).

- **Step 4.3**:
  - Modernized `archive/UpdateFPS.ahk` into production `Lib/UpdateFPS.ahk`:
    - Robust path discovery via `GetFPSPath()` utilizing `ResolveAppPath` INI cache and `SafeFileExist` checks across mapped drives (`F:`, `W:`, `X:`, `P:`, `S:`, `T:`, `C:`), UNC shares (`\\sql1`, `\\wbsql1`, `\\chfsapp1`, `\\agcfsapp1`, `\\app1`), and local Program Files.
    - Launches `FAS.EXE -r` with cleanup of any existing instance via `TerminateProcessGracefully`.
    - Handles "Log User Into System" modal with `InputBox` password entry and graceful cancellation.
    - Dismisses "Open a Client" dialog via `btnCancel` automation.
    - Navigates "Check for Updates" via UIA MenuItem and keyboard accelerator (`!h` -> `u`) fallback.
    - Compares version labels in "Web Updates" (`lblWebVersion` vs `lblVersion`), returning standardized `" - No updates"`, `" - Updates installed"`, `" - Updates available (Manual)"`, or `" - Error (<Reason>)"`.
  - Registered `FPS` in `Core/AppRegistry.ahk` (Category 1: interactive upfront credentials) and wired `#Include <UpdateFPS>` into `NMGIUpdates.ahk`.
  - Updated `PROJECT_SPEC.md` active modules list.
  - Fixed compiled binary crash (`This value of type "String" has no property named "Name"`): removed redundant nested `ResolveAppPath` call in `GetFPSPath()` and made `ResolveAppPath` polymorphic to safely handle string inputs.

### Tested
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly after integrating `Lib/UpdateFPS.ahk`.
- Recompiled `NMGIupdates.exe` via `Ahk2Exe.exe` and smoke tested the compiled binary; confirmed clean startup with zero runtime errors.
- Live verification confirmed by operator on live Practice CS workstation (`CSConnect-debug.log`):
  - `Toolbar Invoke returned after 3031 ms (bound 1500 ms)` - blocking call bounded, no thread freeze or spinning cursor.
  - `Tier A: Call Now control = WindowsForms10.BUTTON.app.* [hwnd]` detected `Call N&ow`.
  - `Practice: Call Now result = A:ControlClick` immediately triggered and dismissed dialog in <50ms.
- Confirmed `UIA.TransactionTimeout` bounding completely eliminates the prior 40-second freeze.
- Tier B updated to include `!o` accelerator fallback in addition to `{Enter}` and `!n`.
- **Step 4.3c**:
  - Enhanced `Lib/UpdateFPS.ahk`:
    - Added UIA visual highlighting to version elements in Web Updates (`lblWeb.Highlight(-3000, "Green", 3)` and `lblCur.Highlight(-3000, "Blue", 3)`) with 1.5s dwell for clear operator feedback.
    - Implemented `DismissWebRegistration(10)` to detect the post-update "Web Registration" dialog ("Do you want to run FAS Accounting?") and select "No" via UIA Click, ControlClick, and `Alt+N` fallbacks.
  - Priority Ordering in `Core/AppRegistry.ahk`:
    - Moved FPS to index 1 of `global Apps` and assigned `Category 0` in `GetAppCategory()`, ensuring Financial Planning Suite launches first before all other applications (including Accounting CS and Practice CS) so the operator enters manual credentials immediately at startup.

- **Step 4.4**:
  - Implemented `Lib/UpdatePPC.ahk`:
    - Discovers `PPCWebMultiSelect.exe` via `GetPPCPath()`.
    - Terminates any previous installer instances cleanly via `TerminateProcessGracefully`.
    - Handles `Thomson Reuters Setup - Installation Type` window, selecting "Next >".
    - Handles `Thomson Reuters Setup - Client` window, inspecting TreeView and CheckBox elements under "Products to be Installed:".
    - Evaluates `ToggleState` (and `DumpAll` patterns); if any item is checked, marks `" - Updates available (Manual)"`; if no items are checked, marks `" - No updates"`.
    - Dismisses the installer via "Cancel" / `!c` and terminates process cleanly.
  - Registered `PPC` in `Core/AppRegistry.ahk` (`Apps` array, Category 2: Automated TR apps).
  - Wired `#Include <UpdatePPC>` into `NMGIUpdates.ahk`.
  - Updated `PROJECT_SPEC.md` active modules list.

### Tested
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly.
- Recompiled `NMGIupdates.exe` via `Ahk2Exe.exe` and smoke tested the compiled binary; confirmed clean startup with zero runtime errors (`Running: True (PID: 14780)`).
- Validated category ordering logic: Category 0 (`FPS`) runs first upfront, followed by Category 1 interactive TR apps (`Accounting CS`, `Practice CS`), Category 2 automated TR apps (`UltraTax`, `FileCabinet`, `Fixed Assets`, `PPC`), Category 3 (`QuickBooks`), Category 4 (`Lacerte`, `Adobe`), and Category 5 (`Browsers`).

### Unfinished Logic / Known Quirks Documented
- Do not spawn helper scripts/processes via `A_AhkPath`/`A_ScriptDir` from compiled `NMGIupdates.exe`: for compiled scripts this relaunches Jacro itself and `#SingleInstance force` kills the running instance (the "Could not close the previous instance" prompt). Keep all logic in-process.

### Next Step / Status
- Step 4.4 complete.
- Ready for Step 4.5: End-to-End Suite Smoke & Packaging (verifying all active modules, reviewing CHANGELOG.md for Milestone 4 wrap-up).






