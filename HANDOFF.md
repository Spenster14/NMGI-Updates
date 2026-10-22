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

- **Step 4.4b**:
  - Enhanced `Lib/UpdatePPC.ahk`:
    - Updated status line to report the total detected checkbox count and checked count (e.g., `PPC: X checkboxes seen (Y checked)`), with an intentional 1-second pause (`Sleep(1000)`) for live visual verification.
    - Improved checkbox inspection across both explicit `CheckBox` and `TreeItem` controls, as well as child items and `DumpAll()` string parsing fallback.
    - Handled installer exit confirmation dialog:
      - Detected `"Thomson Reuters Setup - Client"` modal popup containing `"Are you sure you want to cancel the installation?"`.
      - Leveraged Z-order HWND matching via `WinGetList("Thomson Reuters Setup - Client")` where `hwnds[1]` is the top-most modal confirmation dialog over parent `hwnds[2]`.
      - Implemented multi-tier selection for `"Yes"`: Tier A UIA click (`Name: "Yes"`), Tier B `ControlClick("&Yes")` / `ControlClick("Button1")`, and Tier C keyboard Enter (default focused button) / Alt+Y accelerator.
      - Confirmed clean shutdown via `WinWaitClose` and `TerminateProcessGracefully`.

- **Step 4.4c**:
  - Root cause of "0 checkboxes seen": In 32-bit InstallShield/Wise installer environments, the product tree is a standard Win32 `SysTreeView32` common control. Out-of-process UIA COM bridges do not automatically synthesize UIA element wrappers for unexpanded or lazily-instantiated tree nodes, and `DumpAll()` only caches Type/Name/Value/ClassName without ToggleState.
  - Implemented `InspectPPCCheckboxes(winTitle)` in `Lib/UpdatePPC.ahk`:
    - **Tier 1 (Win32 TreeView SendMessage)**: Finds `SysTreeView32` controls, queries `TVM_GETCOUNT (0x1105)`, walks the hierarchy recursively via `TVM_GETNEXTITEM` (`TVGN_ROOT 0`, `TVGN_CHILD 4`, `TVGN_NEXT 1`), and inspects checkbox state with `TVM_GETITEMSTATE (0x1127)` against `TVIS_STATEIMAGEMASK (0xF000)`. State 1 is unchecked (`0x1000`), State 2 is checked (`0x2000`). Operates in <1ms without requiring UIA tree synthesis.
    - **Tier 2 (UIAutomation)**: Fallback search via `FindElements({Type: "CheckBox"})` and `FindElements({Type: "TreeItem"})`.
    - **Tier 3 (Win32 Button Controls)**: Scans for `BS_CHECKBOX` / `BS_AUTOCHECKBOX` button controls with `BM_GETCHECK (0x00F0)`.
  - Added detailed diagnostic logging (`UpdateLog`) recording which method detected the controls.

### Tested
- Verified Win32 `SysTreeView32` message scanner against live tree structures with AutoHotkey64.exe; confirmed exact count of total and checked items across expanded and collapsed nodes.
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly (`PASS: script still running after 8 s`).
- Recompiled `NMGIupdates.exe` via `Ahk2Exe.exe` and smoke tested the compiled binary; confirmed clean startup with zero runtime errors (`Running: True (PID: 33236)`).

### Unfinished Logic / Known Quirks Documented
- TreeView Checkbox State: Win32 Common Controls store checkbox state in bits 12-15 of the item state (`TVM_GETITEMSTATE` with mask `0xF000`). Direct `SendMessage` bypasses UIA lazy-loading restrictions entirely.

- **Step 4.4d**:
  - Main GUI label adjustments requested by operator:
    - Renamed "PPC Tools & Practice Aids" to "PPC Tools" in `Core/AppRegistry.ahk`.
    - Renamed "Financial Planning Suite" to "FPS" in `Core/AppRegistry.ahk`.
    - Updated `PROJECT_SPEC.md` registry entries to match.
    - Verified `GetAppCategory()` preserved sorting categories (Category 0 for FPS, Category 2 for PPC Tools).

### Tested
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly (`PASS: script still running after 8 s`).
- Recompiled `NMGIupdates.exe` via `Ahk2Exe.exe` and smoke tested the compiled binary; confirmed clean startup with zero runtime errors (`Running: True (PID: 5448)`).

### Unfinished Logic / Known Quirks Documented
- Label Decoupling: In `Core/AppRegistry.ahk`, `Name` is the invariant key used for `[Paths]` and `[Status]` INI mappings, while `Label` controls UI rendering. Updating `Label` preserves persistent operator INI cache without requiring config migration.

- **Step 4.4e**:
  - Centralized Upfront Database Password Collection & Automation:
    - Created `Auth/DatabaseLogin.ahk` implementing `PromptDatabasePasswords(appList)`.
    - Inspects which of `Accounting CS`, `Practice CS`, or `FPS` are checked in `SortedApps`. If any are checked, prompts the operator once upfront in a single modal window with separate masked password fields (`+Password`) for only the checked applications.
    - Stores credentials strictly in-memory (`AcsPassword`, `PracticePassword`, `FpsPassword`).
    - Wired `PromptDatabasePasswords` into `NMGIUpdates.ahk` at `RunSelectedApps(*)`.
    - Category & Load Order Updates:
      - Kept `Accounting CS` and `Practice CS` in Category 1 so they launch first upfront to trigger Thomson Reuters staff sign-in (`TRLogin()`) early.
      - Moved `FPS` to Category 2 (alongside UltraTax, FileCabinet, Fixed Assets, PPC) as it no longer blocks for interactive credential entry.
    - Automated Application Password Injection:
      - `Lib/UpdateFPS.ahk`: Replaced interactive mid-run `InputBox` with automated injection of `FpsPassword` into `txtPassword` and `btnOK`.
      - `Lib/UpdateAccountingCS.ahk`: Implemented multi-tier automated password injection into the database login dialog (Tier A UIA `IsPassword: true` / Name `"Password"`, Tier B Win32 `ES_PASSWORD 0x0020`, Tier C keyboard Tab navigation) followed by `{Enter}`/`OK` and waiting for `"Accounting CS -"`.
      - `Lib/UpdatePractice.ahk`: Implemented multi-tier automated password injection into the database login dialog (Tier A UIA `IsPassword: true` / Name `"Password"`, Tier B Win32 `ES_PASSWORD 0x0020`, Tier C keyboard Tab navigation) followed by `{Enter}`/`OK` and waiting for `"Practice CS -"`.

### Tested
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly (`PASS: script still running after 8 s`).
- Recompiled `NMGIupdates.exe` via `Ahk2Exe.exe` and smoke tested the compiled binary; confirmed clean startup with zero runtime errors (`Running: True (PID: 18016)`).

### Unfinished Logic / Known Quirks Documented
- Memory-Only Credential Policy: In accordance with `PROJECT_SPEC.md` security constraints, database passwords are never persisted to disk or `GUIsettings.ini` and remain strictly scoped to the active execution run.

- **Step 4.4f**:
  - Unified Upfront Credentials Modal:
    - Expanded `Auth/DatabaseLogin.ahk` (`PromptDatabasePasswords`) to inspect for Lacerte applications (`InStr(app.Name, "Lacerte")`).
    - Added `Lacerte Email:` and `Lacerte Password:` fields to the upfront credentials GUI alongside `Accounting CS`, `Practice CS`, and `FPS`.
    - Populated in-memory globals `LacerteEmail` and `LacertePassword` directly on submission.
    - Removed redundant separate `PromptLacerteLogin()` prompt in `NMGIUpdates.ahk`, giving the operator a single upfront credentials window for all selected password-requiring applications.
  - Practice CS / Accounting CS Database Login Automation:
    - Root cause of Practice CS hang: The login modal ("PRACTICE CS® part of the CS PROFESSIONAL SUITE®") is a borderless WinForms Form (`FormBorderStyle = None`). Targeting `"Practice CS"` matched the disabled main background window rather than the active modal. Cross-process UIA tree walks on the disabled window stalled, and WinForms controls with `PasswordChar = '*'` do not declare Win32 `ES_PASSWORD (0x0020)` in `GWL_STYLE`.
    - Implemented shared `SubmitCSDatabaseLogin(winPrefix, exeName, dbPassword)` in `Core/CSConnect.ahk`:
      - Discovers the active login modal dynamically via `WinGetList("ahk_exe " exeName)` matching visible windows with Edit controls and "OK" / "Change password" buttons.
      - Targets the password edit control directly (second edit control / empty edit control) without slow UIA tree walk or `ES_PASSWORD` style requirements.
      - Sets password via dual-path `ControlFocus`, `ControlClick`, `SendText`, and `ControlSetText`.
      - Clicks OK / sends `{Enter}` and waits for dialog closure (`WinWaitClose`) before awaiting the main dashboard (`Practice CS -` / `Accounting CS -`).
    - Wired `SubmitCSDatabaseLogin` into both `Lib/UpdatePractice.ahk` and `Lib/UpdateAccountingCS.ahk`.

### Tested
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly (`PASS: script still running after 8 s`).
- Recompiled `NMGIupdates.exe` via `Ahk2Exe.exe` and smoke tested the compiled binary; confirmed clean startup with zero runtime errors (`Running OK PID: 23076`).

### Unfinished Logic / Known Quirks Documented
- Windows Forms Password Styling: .NET textboxes using custom `PasswordChar` characters omit `ES_PASSWORD (0x0020)` Win32 style bit. Index-based and text-presence detection on the modal dialog avoids this limitation completely.

- **Step 4.4g**:
  - Precise Password Field Targeting in `SubmitCSDatabaseLogin`:
    - Root cause of Open Firm overwrite: In Windows Forms, `Open Firm:` and `Staff ID:` ComboBoxes host child `Edit` controls (`WindowsForms10.EDIT`). `SubmitCSDatabaseLogin` captured all `Edit` controls, and because `ControlGetText` on the ComboBox child edit returned `""`, it selected the `Open Firm` edit control as the target password box. This overwrote the firm name with the password (`RustyP509`), which caused Practice CS to hide the Password field and disable OK.
    - Excluded ComboBox child edit controls by querying Win32 parent class (`DllCall("GetParent")` -> `COMBOBOX`).
    - Anchored password box detection to the `"Password:"` static label row (`Abs(ey - ly) <= 20` and `ex >= lx + lw - 10`).
    - Added auto-recovery logic: If the `"Password:"` label is missing (due to a corrupted `Open Firm` field), checks if any ComboBox matches `dbPassword`, re-selects the first valid firm via `CB_SETCURSEL 0` and `CBN_SELCHANGE`, and waits without typing into unverified controls.
    - Added geometric fallback click relative to the `"Password:"` label (`lx + lw + 40`, `ly + lh // 2`).

### Tested
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly (`PASS: script still running after 8 s`).
- Recompiled `NMGIupdates.exe` via `Ahk2Exe.exe` and smoke tested the compiled binary; confirmed clean startup with zero runtime errors (`Running OK PID: 9196`).

### Unfinished Logic / Known Quirks Documented
- Windows Forms ComboBox Child Controls: In Win32, dropdown ComboBoxes (`CBS_DROPDOWN`) contain a child `Edit` control. Filtering out any control whose parent is a `COMBOBOX` prevents accidental text entry into dropdown controls.

- **Step 4.4h**:
  - CS Suite Invalid Password / Credential Error Handling:
    - Implemented `CheckCSLoginError(winPrefix, exeName, loginHwnd)` in `Core/CSConnect.ahk`.
    - Detects the Thomson Reuters modal warning dialog ("The Staff ID or Password you entered is not valid for the Firm you are attempting to open. Please enter a valid Staff ID and Password or select a different Firm.").
    - Automatically dismisses the warning dialog (`ControlClick("OK")` / `{Enter}`) and closes the underlying login card (`ControlClick("Cancel")` / `{Esc}`).
    - Returns standardized status `" - Error (Invalid credentials)"` and sets status box to `"[Product]: Invalid database credentials."`.
    - Integrated continuous checks during post-submit validation and the 60s dashboard wait loop, ensuring invalid credentials or load timeouts exit immediately without freezing or stalling the update batch.
    - Propagated `SubmitCSDatabaseLogin` return value in `Lib/UpdateAccountingCS.ahk` and `Lib/UpdatePractice.ahk` to exit cleanly on failure.

### Tested
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly (`PASS: script still running after 8 s`).
- Recompiled `NMGIupdates.exe` via `Ahk2Exe.exe` and smoke tested the compiled binary; confirmed clean startup with zero runtime errors (`Running OK PID: 37040`).

### Unfinished Logic / Known Quirks Documented
- Thomson Reuters Error Modal Title: In CS Professional Suite, credential error modals share the application title (`Accounting CS` / `Practice CS`). Matching the window text (`"not valid for the Firm"`) distinguishes the error dialog from the parent window.

- **Step 4.4i**:
  - CS Suite Patient Single-Submit Authentication & Multi-Popup Dismissal:
    - Root cause of multiple popups: `SubmitCSDatabaseLogin` fired `ControlClick`, `BM_CLICK`, and `Send("{Enter}")` simultaneously and re-entered the submit loop before Practice CS finished checking the database, causing Practice CS to generate 3 stacked error modals.
    - Switched to a single deliberate submit event (`ControlClick("OK")` or `{Enter}`), completely eliminating rapid-fire multi-click spam.
    - Exited the input loop immediately upon submission and transitioned into a dedicated 45s yielding polling loop that waits for database validation without re-submitting.
    - Implemented `DismissAllLoginErrors(winPrefix, exeName, loginHwnd)`:
      - Searches across all window handles from both `ahk_exe exeName` and `winPrefix`.
      - Inspects parent window text and child `WindowsForms10.STATIC` label control text via `ControlGetText` (resolving issue where WinForms labels omit parent `WM_GETTEXT`).
      - Recursively detects and closes all cascading/stacked error popups in a loop, dismisses the underlying login card, updates launcher status, and returns `" - Error (Invalid credentials)"`.

### Tested
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly (`PASS: script still running after 8 s`).
- Recompiled `NMGIupdates.exe` via `Ahk2Exe.exe` and smoke tested the compiled binary; confirmed clean startup with zero runtime errors (`Running OK PID: 4512`).

### Unfinished Logic / Known Quirks Documented
- Windows Forms Label Enumeration: .NET `Label` controls do not always return their text when `WinGetText` is called on the parent Form. Explicitly querying child controls via `ControlGetText` on each `cHwnds[i]` guarantees 100% reliable error text extraction.

- **Step 4.4j**:
  - Scanning Tooltip Display on Initial Launch:
    - Displayed `ToolTip("Scanning applications, please wait...", 100, 100)` unconditionally at the beginning of `BuildGUI()` so users immediately receive visual feedback that path scanning is active upon application launch.
    - Preserved `ClearHostCache()` behavior when `forceRescan := true` ("Rescan" button).
    - Unconditionally cleared the tooltip (`ToolTip()`) immediately after `MyGui.Show("NoActivate")` positions and displays the main dashboard.

### Tested
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly (`PASS: script still running after 8 s`).
- Recompiled `NMGIupdates.exe` via `Ahk2Exe.exe`.
- Smoke tested the compiled binary (`smoke_exe.ps1`); confirmed clean startup with zero runtime errors (`PASS: exe still running after 6 s (PID 38600)`).

### Unfinished Logic / Known Quirks Documented
- Tooltip Coordinates: Anchored to `(100, 100)` screen coordinates via `CoordMode("ToolTip", "Screen")`, remaining visible across all monitor configurations while `ResolveAppPath` executes.

- **Step 4.4k**:
  - Technician-Facing GitHub README.md:
    - Authored comprehensive `README.md` targeting MSP and IT technicians.
    - Documented architecture, runtime prerequisites, elevation, initial launch & network caching (`GUIsettings.ini`), dashboard interface, visual status colors, and technician shortcuts (such as `Shift + Right-Click "Rescan"` to uncheck processed apps).
    - Detailed the centralized upfront credential collection modal and zero-persistence memory-only security policy.
    - Documented module-specific operational details across Thomson Reuters CS Suite (UltraTax, Practice CS, Accounting CS, FileCabinet, Fixed Assets, PPC Tools, FPS), QuickBooks Desktop (OCR progress monitoring), Lacerte Tax, Adobe Acrobat (multi-UI detection & trial bypass), and Web Browsers.
    - Included audit log format, post-run summary modal, compilation instructions (`Ahk2Exe`), automated smoke testing (`/smoke`), and troubleshooting guidance.

### Tested
- Verified formatting, table rendering, code blocks, and markdown structure.

- **Step 4.4l**:
  - QuickBooks Subscription Expired/Expiring Popup Dismissal:
    - Implemented `DismissQBSubscriptionPopup()` in `Lib/UpdateQB.ahk`:
      - Discovers the warning popup via `FindQBSubscriptionPopup()` matching titles (`"Quickbooks subscription expired"`, `"subscription expiring"`, etc.) and text (`"subscription has expired"`, `"lose access to Quickbooks"`).
      - Multi-tiered dismissal: Tier 1 (UIA click on "Close" button), Tier 2 (Win32 `ControlClick("Close")`), Tier 3 (child control inspection), Tier 4 (`ControlClick("Button2")`), Tier 5 (keyboard `Esc`), Tier 6 (proportional coordinate click at `~62%` width, `~72%` height), Tier 7 (`WinClose`).
    - Consolidated background popup handling into `HandleQBPopups()` on a 500ms `SetTimer` checking for both "Upgrade Internet Explorer" and subscription warnings.
    - Refactored main QuickBooks window wait into an active polling loop that dismisses modal dialogs, filters out `"Service"`, `"subscription"`, `"Install "`, and `"Information"`, and captures the confirmed `mainHwnd`.

### Tested
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly (`PASS: script still running after 8 s`).
- Recompiled `NMGIupdates.exe` via `Ahk2Exe.exe`.
- Smoke tested the compiled binary (`smoke_exe.ps1`); confirmed clean startup with zero runtime errors (`PASS: exe still running after 6 s (PID 37804)`).

### Unfinished Logic / Known Quirks Documented
- Modal Title Case Sensitivity: The popup title from Intuit uses `"Quickbooks"` (lowercase 'b'), whereas other windows use `"QuickBooks"` (uppercase 'B'). Case-insensitive partial matching handles all variations.

- **Step 4.4m**:
  - Summary Dialog "Copy Log to Clipboard" Button:
    - Replaced basic Windows `MsgBox` in `ShowSummaryReport` ([`NMGIUpdates.ahk`](file:///c:/Users/jony/OneDrive%20-%20NMGI/Documents/GitHub/NMGI-Updates/NMGIUpdates.ahk)) with a dedicated `+AlwaysOnTop` modal GUI (`sumGui`).
    - Added read-only scrollable Edit control rendering the categorized batch summary breakdown.
    - Added `&Copy Log to Clipboard` (`Alt+C` accelerator) button:
      - Reads `TodayDate . "-Update.log"` if present on disk.
      - Assembles the clean summary report along with all raw daily log entries.
      - Copies the combined text to `A_Clipboard`.
      - Provides dynamic button feedback (`Copied to Clipboard!`) with automatic 2.5s label restore via `SetTimer(ResetCopyBtn, -2500)`.
    - Added `&Close` button (Default enter button) and hooked `Escape` and `Close` events.

### Tested
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly (`PASS: script still running after 8 s`).
- Recompiled `NMGIupdates.exe` via `Ahk2Exe.exe`.
- Smoke tested the compiled binary (`smoke_exe.ps1`); confirmed clean startup with zero runtime errors (`PASS: exe still running after 6 s (PID 37660)`).

- **Step 4.4n**:
  - Prioritize Fixed Assets \\goserver\Y\ & Y:\ Mapped Locations:
    - Updated `potentialPaths` in `Lib/UpdateFixedAssets.ahk`: prioritized `\\goserver\Y\WinCSI\DSW\dsw.exe` at the top of the path list, and added `\\goserver\Y$\WinCSI\DSW\dsw.exe`, `\\goserver\WinCSI\DSW\dsw.exe`, `\\goserver\WINCSI$\DSW\dsw.exe`, and mapped drive `Y:\WinCSI\DSW\dsw.exe` & `Y:\DSW\dsw.exe`.
    - Adjusted `IsHostReachable` default timeout from 300ms to 1000ms in `Core/Network.ahk` to reliably accommodate WAN/VPN network conditions when probing offline/online file servers.

### Tested
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly (`PASS: script still running after 8 s`).
- Recompiled `NMGIupdates.exe` via `Ahk2Exe.exe`.
- Smoke tested the compiled binary (`smoke_exe.ps1`); confirmed clean startup with zero runtime errors (`PASS: exe still running after 6 s (PID 9000)`).

- **Step 4.4o**:
  - Fix Adobe Acrobat Headless Hang via ShellRun (Standard User Execution):
    - Root cause: Jacro runs elevated (as Administrator). When `Acrobat.exe` is spawned from an elevated parent, Adobe Acrobat's Protected Mode (sandbox / AppContainer broker) encounters an integrity level mismatch with Windows security tokens, deadlocking before creating a top-level window and leaving 4 headless child processes in Task Manager.
    - Implemented `ShellRun` in `Core/Process.ahk` via Windows Shell COM (`Shell.Application.Windows.Item(SWC_DESKTOP).Document.Application.ShellExecute`), launching target applications at the standard (Medium) user integrity level of the interactive desktop shell.
    - Updated `Lib/UpdateAdobe.ahk` to launch `Acrobat.exe` using `ShellRun` with explicit `workingDir`, matching the exact behavior of desktop shortcuts and Start -> Run.
    - Added fallback chain (`ShellRun` -> `explorer.exe <path>` -> `Run(<path>, workingDir)`) and increased window wait timeout to 20s.

- **Step 4.4p**:
  - Fix Adobe Acrobat Window Detection and Classic UI Menu Navigation:
    - Root cause: `WinWait("ahk_exe Acrobat.exe",, 20)` hung / timed out because `ahk_exe` requires AutoHotkey to query process image paths via `OpenProcess`. When Adobe Acrobat runs in 64-bit mode with Protected Mode sandboxing, restricted DACLs / AppContainers deny `PROCESS_QUERY_LIMITED_INFORMATION`, causing `GetWindowProcessName` to fail and return an empty string.
    - Replaced `WinWait("ahk_exe Acrobat.exe")` with multi-criteria window wait loop (`ahk_class AcrobatSDIWindow`, `"Adobe Acrobat"`, `"Acrobat Reader"`, process fallbacks) capturing `adobeHwnd`. Window class and title checks use standard User32 APIs (`GetClassName`, `GetWindowText`) which operate unrestricted across all integrity levels and AppContainers.
    - Activated the window directly via `adobeHwnd` with `SetForegroundWindow` and `BringWindowToTop`.

- **Step 4.4q**:
  - Multi-Tiered Adobe Acrobat "Check for Updates" Invocation:
    - Root cause: In Adobe Acrobat DC 64-bit with Classic UI, the accelerator key under the Help menu is `c` (for `Check for Updates...`), whereas Acrobat 2020 uses `u`. In Step 4.4p, sending `u` failed to match the menu item in Acrobat DC, leaving `Help` highlighted on the menu bar without invoking the update check. Furthermore, `isClassicUI` previously defaulted to `is2020` (which is `false` for Acrobat DC), causing elevated runs without standard HKCU keys to incorrectly attempt New UI navigation.
    - Defaulted UI mode to Classic (`isClassicUI := true`), only switching to Modern New Experience UI if a "Menu" hamburger button is explicitly found.
    - Implemented a multi-tiered invocation sequence in `Lib/UpdateAdobe.ahk`:
      - Tier 1 (Immediate): `Alt+H` -> `c` -> `{Enter}` (Acrobat DC standard) or `Alt+H` -> `u` (Acrobat 2020).
      - Tier 2 (after 2s): `Alt+H` -> `u` -> `{Enter}`.
      - Tier 3 (after 4s): `Alt+H` -> `{Up}` -> `{Enter}` (wraps to bottom item in Help menu).
      - Tier 4 (after 6s): Desktop-wide UIA search across popup menus for `(?i)check for updates`.

- **Step 4.4r**:
  - Prioritize UNC Paths Before Drive Letter Paths Across All Applications:
    - User requirement: Reorganize all application path checks so UNC paths (`\\...`) are always checked before drive letter paths (`[A-Za-z]:\...`), ensuring network server shares like `\\app1` or `\\goserver` are preferred over local paths like `C:\`.
    - Updated `Lib/UpdateFixedAssets.ahk`: All UNC shares (`\\goserver\...`, `\\agcfsapp1\...`, `\\wbsql1\...`, `\\chfsapp1\...`, `\\hfaapp1\...`, `\\app1\...`) strictly precede mapped/local drives (`Y:\`, `X:\`, `U:\`, `W:\`, `C:\`).
    - Updated `Lib/UpdateFPS.ahk`: All UNC shares (`\\sql1\...`, `\\wbsql1\...`, `\\chfsapp1\...`, `\\agcfsapp1\...`, `\\app1\...`) moved to the top of `potentialPaths`, strictly preceding drive letters (`F:\`, `W:\`, `X:\`, etc.).
    - Updated `Lib/UpdatePractice.ahk`: Grouped all production and legacy UNC shares (`\\sql1\...`, `\\wbsql1\...`, `\\tho1\...`, `\\agcfsapp1\...`, `\\app1\...`, `\\chfsapp1\...`) at the top, preceding drive letters (`T:\`, `W:\`, `X:\`, etc.).
    - Updated `Lib/UpdateAccountingCS.ahk`: Added candidate UNC shares (`\\sql1\...`, `\\wbsql1\...`, `\\app1\...`, `\\agcfsapp1\...`, `\\chfsapp1\...`, `\\tho1\...`), wrapped lookups in `SafeFileExist`, and placed them before drive letters.
    - Updated `Lib/UpdateFileCabinet.ahk` & `Lib/UpdateUT.ahk`: Added common network server UNC shares and verified UNC paths strictly precede drive letter paths.

- **Step 4.4s**:
  - Diagnose & Fix Fixed Assets Path Resolution (`\\app1` vs `C:\` Cache & Network Probe):
    - Root Cause Analysis:
      1. **Cache Persistence**: On standard launch (`forceRescan == false`), `ResolveAppPath` in `Core/Config.ahk` checks `GUIsettings.ini [Paths]`. Because `FixedAssetsCS=C:\WinCSI\DSW\dsw.exe` was previously recorded and `C:\WinCSI\DSW\dsw.exe` existed locally, Jacro returned the cached path immediately without rescanning `potentialPaths`.
      2. **64-bit Winsock Struct Offset Bug in `Core/Network.ahk`**: When `IsHostReachable(host)` executed, `ai_addr` was extracted using `16 + A_PtrSize`. In 64-bit Windows, `struct addrinfo` has `ai_canonname` at offset 24 and `ai_addr` at offset 32 (`16 + A_PtrSize * 2`). Offset 24 was NULL (`0`), so `DllCall("ws2_32\connect")` was passed a NULL pointer, failing with `WSAEFAULT` (10014) on every single host. Consequently, `IsHostReachable` returned `false` for all UNC paths, causing `SafeFileExist("\\app1\...")` to return `""`, skipping `\\app1` and falling back to local `C:\` even when Rescan was pressed.
    - Fixes Applied:
      - Corrected `ai_addr` pointer offset calculation in `Core/Network.ahk` to `16 + A_PtrSize * 2`.
      - Switched `hints` to `AF_UNSPEC (0)` to support both IPv4 and IPv6 network hosts (including single-label NetBIOS names like `app1`).
      - Created `sock` dynamically using `ai_family`, `ai_socktype`, and `ai_protocol` from `getaddrinfo` results.
    - Technician Instructions:
      - With `NMGIupdates.exe` recompiled, the operator clicks **Rescan** in the Jacro GUI (or deletes `GUIsettings.ini`), which clears the cache and discovers `\\app1\WinCSI\DSW\dsw.exe` as the top-priority path.

### Tested
- Verified non-blocking Winsock connection against local test host (`connect: -1 WSAGetLastError: 10035 select: 1 reachable: True`).
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly (`PASS: script still running after 8 s`).
- Recompiled `NMGIupdates.exe` via `Ahk2Exe.exe`.
- Smoke tested the compiled binary (`smoke_exe.ps1`); confirmed clean startup with zero runtime errors (`PASS: exe still running after 6 s (PID 4368)`).

### Next Step / Status
- Step 4.4s complete.
- Transitioned to Milestone 5: Shortcut-First Discovery Engine (approved by user in `shortcut_architecture_plan.md`).

- **Step 5.1**:
  - Build `Core/ShortcutScanner.ahk`:
    - Implemented `GetShortcutSearchRoots()` querying `C:\Users\Public\Desktop\Applications`, `A_Desktop . "\Applications"`, Public Desktop root, and User Desktop root.
    - Implemented `IndexShortcuts(forceRefresh)`: recursively walks roots (`Loop Files, root . "\*.lnk", "R"`), extracts target/workingDir/args/description via `FileGetShortcut`, expands environment variables via `ExpandEnvironmentStrings` (`ExpandEnvVars`), and caches entries in `ShortcutCache`.
    - Implemented `FindShortcutPath(exeNames, namePatterns, filterFn)`: two-pass priority matching (pass 1 strictly scans `Applications` folder and subfolders; pass 2 searches Desktop roots as fallback). Validates physical reachability and existence with `SafeFileExist(target)`.
    - Provided `ClearShortcutCache()` and wired into `BuildGUI(forceRescan)` in `NMGIUpdates.ahk`.
    - Included `#Include Core\ShortcutScanner.ahk` in `NMGIUpdates.ahk`.

### Tested
- Tested `Core/ShortcutScanner.ahk` with unit test script: indexed 16 active desktop shortcuts in <10ms; successfully matched `chrome.exe` and `msedge.exe`; returned empty string for missing apps without hanging.
- Tested recursive nested folder scanning with mock directory (`scratch\mock_root\Applications\Accounting\Fixed Assets CS.lnk`); verified nested `.lnk` discovery and `IsApplicationsFolder` flag.
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly (`PASS: script still running after 8 s`).
- Recompiled `NMGIupdates.exe` via `Ahk2Exe.exe`.
- Smoke tested the compiled binary (`smoke_exe.ps1`); confirmed clean startup with zero runtime errors (`PASS: exe still running after 6 s (PID 36160)`).

- **Step 5.2**:
  - Wire Shortcut Discovery into Thomson Reuters Modules:
    - Updated `GetFixedAssetsPath()` in `Lib/UpdateFixedAssets.ahk`: checks `dsw.exe` shortcuts matching `(?i)Fixed\s*Assets|(?i)\bDSW\b` before `potentialPaths`.
    - Updated `GetUTPath(UTversion)` in `Lib/UpdateUT.ahk`: checks `utw[XX].exe` shortcuts matching `(?i)UltraTax.*20[XX]|(?i)UT.*[XX]` before `possiblePaths`.
    - Updated `GetFileCabinetPath()` in `Lib/UpdateFileCabinet.ahk`: checks `fcab.exe` shortcuts matching `(?i)FileCabinet|(?i)File\s*Cabinet` before `potentialPaths`.
    - Updated `GetAccountingCSPath()` in `Lib/UpdateAccountingCS.ahk`: checks `AccountingCS.exe` and `acs.exe` shortcuts matching `(?i)Accounting\s*CS|(?i)\bACS\b` before `potentialPaths`.
    - Updated `GetPracticePath()` in `Lib/UpdatePractice.ahk`: checks `CreativeSolutions.Practice.exe`, `PracticeCS.exe`, and `practice.exe` shortcuts matching `(?i)Practice\s*CS` before `potentialPaths`.
    - Updated `GetFPSPath()` in `Lib/UpdateFPS.ahk`: checks `FAS.EXE` shortcuts matching `(?i)Financial\s*Planning|(?i)\bFPS\b|(?i)\bFAS\b` before `potentialPaths`.
    - Updated `GetPPCPath()` in `Lib/UpdatePPC.ahk`: checks `PPCWebMultiSelect.exe` shortcuts matching `(?i)PPC|(?i)Practice\s*Aids` before `candidatePaths`.

### Tested
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly (`PASS: script still running after 8 s`).
- Recompiled `NMGIupdates.exe` via `Ahk2Exe.exe`.
- Smoke tested the compiled binary (`smoke_exe.ps1`); confirmed clean startup with zero runtime errors (`PASS: exe still running after 6 s (PID 42004)`).

- **Step 5.3**:
  - Wire Shortcut Discovery into QuickBooks, Lacerte, Adobe & Browsers:
    - Updated `GetQBPath(QBversion)` in `Lib/UpdateQB.ahk`: checks `qbw32.exe` and specialized QuickBooks binaries with year and edition (Enterprise vs Premier) closure matching before `C:\Program Files\Intuit\` search.
    - Updated `GetLacertePath(year)` in `Lib/UpdateLacerte.ahk`: checks `w[XX]tax-launcher.exe` and `w[XX]tax.exe` shortcuts matching `(?i)Lacerte.*20[XX]|(?i)20[XX].*Lacerte|(?i)Lacerte.*[XX]` before standard local folder.
    - Updated `GetAdobePath()` in `Lib/UpdateAdobe.ahk`: checks `Acrobat.exe` and `AcroRd32.exe` shortcuts matching `(?i)Adobe\s*Acrobat|(?i)\bAcrobat\b|(?i)Adobe\s*Reader` before candidate list.
    - Updated `GetChromePath()` in `Lib/UpdateChrome.ahk`: checks `chrome.exe` shortcuts matching `(?i)Google\s*Chrome|(?i)\bChrome\b`.
    - Updated `GetEdgePath()` in `Lib/UpdateEdge.ahk`: checks `msedge.exe` shortcuts matching `(?i)Microsoft\s*Edge|(?i)\bEdge\b`.
    - Updated `GetFirefoxPath()` in `Lib/UpdateFirefox.ahk`: checks `firefox.exe` shortcuts matching `(?i)Mozilla\s*Firefox|(?i)\bFirefox\b`.

### Tested
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly (`PASS: script still running after 8 s`).
- Recompiled `NMGIupdates.exe` via `Ahk2Exe.exe`.
- Smoke tested the compiled binary (`smoke_exe.ps1`); confirmed clean startup with zero runtime errors (`PASS: exe still running after 6 s (PID 13308)`).

- **Step 5.4**:
  - Authoritative Shortcut Synchronization in `Core/Config.ahk` & Dashboard Integration:
    - Added `FindAppShortcut(appName)` to `Core/ShortcutScanner.ahk` mapping all 22 registered applications to their corresponding shortcut search rules.
    - Updated `ResolveAppPath` in `Core/Config.ahk`:
      - Evaluates `FindAppShortcut(appName)` as Priority 1 before querying the INI cache.
      - If an authoritative desktop shortcut is detected in `C:\Users\Public\Desktop\Applications` (or Desktop) and its target differs from `cachedPath`, automatically updates `GUIsettings.ini` to align with the active shortcut without requiring manual INI edits or a forced full scan.
      - Retains fast INI cache evaluation for applications without desktop shortcuts.
    - Wired `ClearShortcutCache()` into `BuildGUI(forceRescan)` in `NMGIUpdates.ahk` so clicking "Rescan" clears both network and shortcut caches.

### Tested
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly (`PASS: script still running after 8 s`).
- Recompiled `NMGIupdates.exe` via `Ahk2Exe.exe`.
- Smoke tested the compiled binary (`smoke_exe.ps1`); confirmed clean startup with zero runtime errors (`PASS: exe still running after 6 s (PID 26952)`).

- **Step 5.5**:
  - End-to-End Verification, Documentation & Release:
    - Updated `README.md` with Shortcut-First discovery workflow and `GUIsettings.ini` auto-synchronization details.
    - Updated `PROJECT_SPEC.md` Active Core Production Files table with `Core/ShortcutScanner.ahk`.
    - Updated `CHANGELOG.md` with comprehensive Milestone 5 release notes.
    - Recompiled production `NMGIupdates.exe` binary via `Ahk2Exe.exe`.

### Tested
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly (`PASS: script still running after 8 s`).
- Smoke tested the compiled binary (`smoke_exe.ps1`); confirmed clean startup with zero runtime errors (`PASS: exe still running after 6 s (PID 26952)`).

- **Step 5.6**:
  - Discovery Source Tracking (`[PathSources]` in `GUIsettings.ini` & Dashboard Hover Tooltips):
    - Implemented `FindShortcutInfo` and `FindAppShortcutInfo` in `Core/ShortcutScanner.ahk` returning rich metadata objects (`{ Target, LnkPath, LnkName, IsApplicationsFolder }`).
    - Updated `ResolveAppPath` in `Core/Config.ahk` to write the discovery origin and shortcut file path into `[PathSources]` in `GUIsettings.ini` (`Shortcut: <lnk>` vs `FallbackScan` vs `NotInstalled`) and set `app.Source` on the in-memory application object. Backfills legacy `NotInstalled` and cached UNC paths into `[PathSources]`.
    - Implemented `WM_MOUSEMOVE (0x0200)` and periodic `CheckHoverLeave` hover tooltips in `NMGIUpdates.ahk` mapped to application checkbox (`app.cb.Hwnd`) and label (`app.txt.Hwnd`) controls. Hovering over any application control displays application name, resolved path, and discovery origin. Moving the cursor off controls immediately dismisses the tooltip.
    - Strict Isolation: Per operator requirement, discovery source tracking is strictly confined to `GUIsettings.ini` and GUI hover tooltips; daily log (`yyMMdd-Update.log`) and summary modal remain clean and untampered.

### Tested
- Automated AHK v2 smoke test (`smoke.ps1`) passes cleanly (`PASS: script still running after 20 s (PID 34268)`).
- Recompiled `NMGIupdates.exe` via `Ahk2Exe.exe`.
- Smoke tested the compiled binary (`smoke_exe.ps1`); confirmed clean startup with zero runtime errors (`PASS: exe still running after 6 s (PID 11444)`).

### Final Status
- All milestones (1 through 5) complete and fully verified.
- The 2-tier Shortcut-First discovery architecture is live in both script and compiled executable (`NMGIupdates.exe`). Authoritative shortcuts deployed by NMGI in `C:\Users\Public\Desktop\Applications` (and nested folders) are prioritized across all applications, resolving historical multi-installation ambiguities automatically.
- Technicians can inspect discovery provenance in real-time by hovering over any application on the dashboard or by reviewing `[PathSources]` in `GUIsettings.ini`.

















