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

### Next Step / Status
- Step 4.4h complete. Ready for operator testing of `NMGIupdates.exe` on live workstation.
- Next step upon user confirmation: Step 4.5: End-to-End Suite Smoke & Packaging (verifying all active modules, reviewing CHANGELOG.md for Milestone 4 wrap-up).










