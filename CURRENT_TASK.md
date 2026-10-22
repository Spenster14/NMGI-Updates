# Current Task Tracker: Modernizing Jacro Architecture

## Status
- **Current Phase**: Shortcut-First Discovery Engine (Milestone 5)
- **Active Step**: Step 5.2: Wire Shortcut Discovery into Thomson Reuters Modules
- **Rule Constraints**: Maintain atomic commits. Follow Pre-Execution Checkpoint Protocol.

---

## The First 3 Logical Milestones

### Milestone 1: Repository Hygiene & Dead Code Retirement
*Goal: Purge dead code, test artifacts, unreferenced libraries, and tracked binaries to establish a clean, lightweight baseline.*

- [x] **Step 1.1**: Git Hygiene & Binaries Removal (also untracked per-machine `GUIsettings.ini`)
  - Untrack and remove compiled executables from repository tracking (`CheckboxGUItest.exe`, `FindDomain.exe`, `GUITest.exe`, `GetDomain.exe`, `NMGIupdates.exe`, `NMGIupdates.exe.fake3`, `TestChrome.exe`, `firefoxdump.exe`).
  - Create `.gitignore` to prevent tracking of `*.exe`, `*.log`, `*.bak`, and temporary dump files.
- [x] **Step 1.2**: Remove Dead Scratch & Test Scripts
  - Remove deprecated root scripts: `connectwise.ahk`, `TestChrome.ahk`, `test_cb.ahk`, `test_cb2.ahk`, `GetDomain.ahk`.
  - Archive/remove legacy prototype `GUITest.ahk`.
- [x] **Step 1.3**: Prune Unreferenced Dependencies & Backup Files in `Lib/` (Adobe/FPS moved to `archive/`)
  - Remove unused external library `Lib/FindText.ahk` (126 KB, 0 references).
  - Remove obsolete OCR backups: `Lib/PreChange250904UpdateEdge.ahk`, `Lib/Preupdate250904UpdateChrome.ahk`.
  - Remove one-off tree dumpers: `Lib/DumpACS.ahk`, `Lib/DumpFirefoxUIA.ahk`.
  - Preserve `Lib/OCR.ahk` (actively required by `UpdateQB.ahk` for progress bar monitoring).
- [x] **Step 1.4**: Establish Canonical Main Entry Point
  - Renamed `CheckboxGUItest.ahk` to `NMGIUpdates.ahk` reflecting its production status rather than a test harness name.
  - Verify syntax and successful compilation/run using AHK v2.

---

### Milestone 2: Modular Architecture & Core Service Extraction
*Goal: Decouple presentation, application registry, authentication flows, and common utility routines into clean, maintainable modules.*

- [x] **Step 2.3**: Common Utilities & State Logging
  - Extracted log engine (`UpdateLog`, `GetAppStatus`, `GetColorByStatus`) into dedicated `Core/Logger.ahk` (`d012ce5`).
- [x] **Step 2.2**: Centralize Shared Authentication & Dialog Services
  - [x] Extracted bulletin and startup popup handlers (`HandleBulletins`) into `Auth/Bulletins.ahk` (`2563e5b`).
  - [x] Extracted Thomson Reuters login orchestration (`TRLogin`, `CloseSignInTR`) into `Auth/TRLogin.ahk` (`cf68a84`).
  - [x] Extracted Lacerte upfront authentication modal into `Auth/LacerteLogin.ahk` and wired into `NMGIUpdates.ahk` (`06e6815`).
- [x] **Step 2.1**: Declarative Application Registry
  - Extracted the application definition list (`Apps` array), `GetAppCategory`, and `SortApps` into `Core/AppRegistry.ahk` (`a538a48`).
  - Maintained correct load order (included above `BuildGUI()`).
- [x] **Step 2.4**: INI Cache Decoupling
  - Encapsulated `[Paths]` cache operations into `Core/Config.ahk` (`ResolveAppPath`).
  - Refactor `GUIsettings.ini` usage to drop legacy domain pipe mappings and standardize strictly on the `[Paths]` cache.

---

### Milestone 3: Interface Standardization & Error Resilience
*Goal: Standardize the updater module contract across all applications and harden network/UI edge cases.*

- [x] **Step 3.1**: Standardize Module Return Types & Signatures
  - Standardized all `Update*.ahk` return strings with consistent `" - "` prefix, `" - Updates installed"`, `" - No updates"`, `" - Updates available (Manual)"`, and `" - Error (<Reason>)"`.
  - Replaced abrupt `ExitApp` in `UpdateQB.ahk` with graceful error returns to preserve batch execution.
  - Eliminated duplicate `FileAppend` calls and redundant variables in `UpdateLacerte.ahk`.
  - Stripped redundant commented-out legacy blocks across all updater modules in `Lib/` and `Core/Logger.ahk`.
- [x] **Step 3.2**: Network UNC Reachability Guards
  - Extracted `Core/Network.ahk` implementing fast non-blocking Winsock connection checks (`IsHostReachable`) with per-session caching (`HostCache`).
  - Added `SafeFileExist(path)` to intercept UNC queries and instantly bypass unreachable hosts (reducing scan times from ~30s per file to ~0ms after the first host probe).
  - Integrated `SafeFileExist` into `Core/Config.ahk`, `Lib/UpdateFixedAssets.ahk`, `Lib/UpdateUT.ahk`, and `Lib/UpdateFileCabinet.ahk`.
  - Wired `ClearHostCache()` into `NMGIUpdates.ahk` to refresh host state whenever the operator clicks "Rescan".
- [x] **Step 3.3**: Hardening Status & Recovery Logic
  - Extracted `Core/Process.ahk` providing `TerminateProcessGracefully(exeName, waitSeconds, forceKill)` and WMI-based `KillProcessesByPrefix(prefix)`.
  - Replaced repetitive process kill blocks across `Lib/UpdateChrome.ahk`, `Lib/UpdateEdge.ahk`, `Lib/UpdateFirefox.ahk`, `Lib/UpdateQB.ahk`, and `NMGIUpdates.ahk`.
  - Added `ShowSummaryReport(results)` to `NMGIUpdates.ahk` displaying a categorized report dialog (Updated, Already Current, Attention Required, Errors) upon batch completion.
- [x] **Step 3.4**: Final Verification & Documentation Update
  - Verified clean syntax, symbol resolution, and startup execution via automated smoke tests (`smoke.ps1`).
  - Successfully validated live end-to-end execution on operator test machine.
  - Updated `CHANGELOG.md` with complete architecture transition notes across Milestones 1, 2, and 3.

---

### Milestone 4: Modernizing Archived Modules & Expansion
*Goal: Modernize archived/dormant modules, standardize their interfaces, and safely integrate them into the production dashboard.*

- [x] **Step 4.1**: Modernize `Lib/UpdateAdobe.ahk`
  - [x] Implement `Lib/UpdateAdobe.ahk` with `GetAdobePath() -> String` and `Adobe(args*) -> String`.
  - [x] Register `{ Name: "Adobe Acrobat", Label: "Adobe Acrobat", fn: (*) => Adobe(), pathFn: (*) => GetAdobePath() }` in `Core/AppRegistry.ahk`.
  - [x] Uncomment `#Include <UpdateAdobe>` in `NMGIUpdates.ahk`.
  - [x] Run smoke test verification via `smoke.ps1` to ensure clean parsing and load.
  - [x] Atomically commit Step 4.1.
- [x] **Step 4.2**: Add and Integrate `Lib/UpdatePractice.ahk`
  - [x] Create `Lib/UpdatePractice.ahk` with `GetPracticePath() -> String` and `Practice(PostUpdate := false) -> String`.
  - [x] Register `{ Name: "PracticeCS", Label: "Practice CS", fn: (*) => Practice(), pathFn: (*) => GetPracticePath() }` in `Core/AppRegistry.ahk`.
  - [x] Update `GetAppCategory` in `Core/AppRegistry.ahk` so interactive database-login apps (Accounting CS & Practice CS) sort to the beginning of Category 1.
  - [x] Add `#Include <UpdatePractice>` in `NMGIUpdates.ahk`.
  - [x] Update `PROJECT_SPEC.md` module registry.
  - [x] Run smoke test verification via `smoke.ps1` to ensure clean parsing and load.
  - [x] Atomically commit Step 4.2.
- [x] **Step 4.2b**: Add `\\sql1` locations to `Lib/UpdatePractice.ahk`
  - [x] Add `\\sql1\WinCSI\Practice CS\PracticeCS.exe`, `\\sql1\WINCSI$\Practice CS\PracticeCS.exe`, and `practice.exe` variants.
  - [x] Run smoke test verification via `smoke.ps1`.
  - [x] Atomically commit Step 4.2b.
- [x] **Step 4.2c**: Update Practice CS binary name to `CreativeSolutions.Practice.exe` and add `T:\Practice CS\`
  - [x] Update `GetPracticePath` in `Lib/UpdatePractice.ahk` prioritizing `\\sql1\winCSI\Practice CS\CreativeSolutions.Practice.exe` and `T:\Practice CS\CreativeSolutions.Practice.exe`.
  - [x] Run smoke test verification via `smoke.ps1`.
  - [x] Atomically commit Step 4.2c.
- [x] **Step 4.2d**: Fix CS Connect & Call Summary Button Acknowledgment in `Lib/UpdatePractice.ahk`
  - [x] Add explicit timeouts to `WaitElement` in CS Connect ("Call Now" / "Connect") and Call Summary (`Document` / `Edit` / `Text`).
  - [x] Implement multi-tiered button dismissal (UIA -> ControlClick -> Enter/Space -> WinClose) for both `Call Summary` and underlying `Online Status` windows.
  - [x] Run smoke test verification via `smoke.ps1`.
  - [x] Atomically commit Step 4.2d.
- [x] **Step 4.2e**: Fix False-Positive Update Detection in `Lib/UpdatePractice.ahk`
  - [x] Use `callSumEl.DumpAll()` and `WinGetText("Call Summary")` to reliably parse "No new updates are available".
  - [x] Gate `" - Updates available (Manual)"` on confirmed detection of the `"Apply Updates"` dialog rather than defaulting on read failures.
  - [x] Run smoke test verification via `smoke.ps1`.
  - [x] Atomically commit Step 4.2e.
- [x] **Step 4.2f**: Non-freezing CS Connect launch + robust "Call Now" click (Practice CS & Accounting CS) — *baseline reset to `7410370`; prior 4.2f–4.2l experiments were rolled back*
  - Diagnosis: `btn.Click()` => UIA `Invoke()` is a synchronous cross-process call; the CS Connect toolbar button opens a MODAL dialog so Invoke does not return until UIA's timeout (~20-40s). Jacro's single thread is blocked (busy cursor, status stuck on "Waiting for ... Connect button...").
  - Plan:
    - [x] New `Core/CSConnect.ahk` (shared by both modules, included from `NMGIUpdates.ahk`): `InvokeNoFreeze(btn)` bounds `UIA.TransactionTimeout` (restored afterwards) around the single blocking Invoke.
    - [x] Poll for the dialog with yielding `Sleep(100)` loop (GUI stays responsive); match `CS Connect ahk_exe <exe of the main window>` with TitleMatchMode 2; hidden-window fallback (setting restored).
    - [x] "Call Now" tiers: (a) exact-text control match -> `ControlClick` then `BM_CLICK` post; (b) `WinActivate` + `{Enter}` (default button) then `!n`; (c) client-relative coordinate click.
    - [x] Diagnostics: HWND + control list (hwnd/class/text) to `CSConnect-debug.log` used during investigation; removed once verified in live testing.
    - [x] Smoke test via `smoke.ps1`; mock-dialog tests of tiers A and C pass (tier B needs a live interactive desktop).
    - [x] Live operator verification confirmed: `InvokeNoFreeze` bounded to 3s (from 40s freeze), `Tier A: Call Now control` detected (`WindowsForms10.BUTTON.app.*`), and `A:ControlClick` successfully dismissed the dialog with zero GUI freeze. Step 4.2f complete.
- [x] **Step 4.3**: Modernize `archive/UpdateFPS.ahk` into `Lib/UpdateFPS.ahk`
  - [x] Implement `GetFPSPath() -> String` with INI cache resolution (`ResolveAppPath`) and candidate paths via `SafeFileExist`.
  - [x] Implement `FPS(PostUpdate := false) -> String`:
    - Launch executable (`FAS.EXE -r`).
    - Handle modal login ("Log User Into System") with graceful cancel support.
    - Dismiss "Open a Client" dialog via `btnCancel`.
    - Navigate menu to "Check for Updates" with keyboard fallback (`!h` -> `u`).
    - Compare version labels in "Web Updates" (`lblWebVersion` vs `lblVersion`).
    - Return standardized status strings (`" - No updates"`, `" - Updates installed"`, `" - Updates available (Manual)"`, `" - Error (<Reason>)"`).
  - [x] Register `FPS` in `Core/AppRegistry.ahk` (Category 1: interactive upfront login).
  - [x] Uncomment `#Include <UpdateFPS>` in `NMGIUpdates.ahk`.
  - [x] Validate via `smoke.ps1`.
  - [x] Bugfix: Remove redundant nested `ResolveAppPath` call from `GetFPSPath` and make `ResolveAppPath` polymorphic to safely accept both `String` and `App` object. Verified with compiled `NMGIupdates.exe` smoke test.
  - [x] Atomically commit Step 4.3.
- [x] **Step 4.3c**: FPS Visual Highlighting, Web Registration Dismissal, & Priority Ordering
  - [x] Add UIA `.Highlight()` to version comparison elements (`lblWebVersion` and `lblVersion`) in `Lib/UpdateFPS.ahk`.
  - [x] Implement `DismissWebRegistration()` in `Lib/UpdateFPS.ahk` to wait for and dismiss "Web Registration" ("Do you want to run FAS Accounting? -> No").
  - [x] Assign Category 0 to FPS in `Core/AppRegistry.ahk` so it sorts before all other applications (including Accounting CS & Practice CS).
  - [x] Validate via smoke test (`smoke.ps1`) and compile verification.
- [x] **Step 4.4**: Add and Integrate `Lib/UpdatePPC.ahk` (Thomson Reuters PPC Tools & Practice Aids Installer)
  - [x] Implement `GetPPCPath() -> String` checking `"C:\Program Files (x86)\Common Files\PPC\PPCWebMultiSelectInstaller\PPCWebMultiSelect.exe"` and 64-bit variant.
  - [x] Implement `PPC(PostUpdate := false) -> String`:
    - Launch `PPCWebMultiSelect.exe` (with prior process cleanup via `TerminateProcessGracefully`).
    - Handle `Thomson Reuters Setup - Installation Type` window: click "Next >".
    - Handle `Thomson Reuters Setup - Client` window: inspect TreeView checkbox items in "Products to be Installed:".
    - If any checkbox is checked: return `" - Updates available (Manual)"`.
    - If no checkboxes are checked: return `" - No updates"`.
    - Dismiss the installer cleanly by clicking "Cancel" (or sending `!c`).
    - Standard error handling for timeouts or missing paths.
  - [x] Register `PPC` in `Core/AppRegistry.ahk` (Category 2: Automated TR apps).
  - [x] Add `#Include <UpdatePPC>` to `NMGIUpdates.ahk`.
  - [x] Atomically commit Step 4.4.
- [x] **Step 4.4b**: PPC Confirmation Dismissal & Status Checkbox Count
  - [x] Update status to display number of detected checkboxes and checked count, then pause for 1 second.
  - [x] After clicking Cancel, wait for "Thomson Reuters Setup - Client" ("Are you sure you want to cancel the installation?") and click "Yes".
  - [x] Validate via smoke test (`smoke.ps1`) and compile verification.
  - [x] Atomically commit Step 4.4b.
- [x] **Step 4.4c**: Fix PPC Checkbox Detection via Win32 TreeView Messages
  - [x] Implement `InspectPPCCheckboxes(winTitle)` in `Lib/UpdatePPC.ahk`:
    - Tier 1: Win32 `SysTreeView32` native `SendMessage` (`TVM_GETCOUNT`, `TVM_GETNEXTITEM`, `TVM_GETITEMSTATE` with `TVIS_STATEIMAGEMASK 0xF000`).
    - Tier 2: UIA `CheckBox` and `TreeItem` fallback.
    - Tier 3: Win32 `BS_CHECKBOX` button enumeration.
  - [x] Update launcher status line with detected checkbox and checked count, pause for 1s.
  - [x] Validate via `smoke.ps1` and recompile `NMGIupdates.exe`.
  - [x] Atomically commit Step 4.4c.
- [x] **Step 4.4d**: GUI Label Tweaks
  - [x] Rename "PPC Tools & Practice Aids" to "PPC Tools" in `Core/AppRegistry.ahk`.
  - [x] Rename "Financial Planning Suite" to "FPS" in `Core/AppRegistry.ahk`.
  - [x] Verify sorting category in `GetAppCategory()` preserves order (Category 0 for FPS, Category 2 for PPC Tools).
  - [x] Validate via `smoke.ps1` and recompile `NMGIupdates.exe`.
  - [x] Atomically commit Step 4.4d.
- [x] **Step 4.4e**: Centralized Upfront Database Password Collection & Automation
  - [x] Create `Auth/DatabaseLogin.ahk` (`PromptDatabasePasswords`) presenting a single modal for checked database apps (`Accounting CS`, `Practice CS`, `FPS`) with separate masked password fields.
  - [x] Wire `PromptDatabasePasswords` and `#Include <Auth/DatabaseLogin>` into `NMGIUpdates.ahk` at `RunSelectedApps(*)`.
  - [x] Update `Core/AppRegistry.ahk`: move `FPS` to Category 2, keep `Accounting CS` & `Practice CS` in Category 1.
  - [x] Update `Lib/UpdateFPS.ahk` to consume in-memory `FpsPassword` without prompting mid-run.
  - [x] Update `Lib/UpdateAccountingCS.ahk` to detect login modal and automate password submission using `AcsPassword`.
  - [x] Update `Lib/UpdatePractice.ahk` to detect login modal and automate password submission using `PracticePassword`.
  - [x] Validate via `smoke.ps1` and recompile `NMGIupdates.exe`.
  - [x] Atomically commit Step 4.4e.
- [x] **Step 4.4f**: Fix Practice CS Database Login Automation & Unify Lacerte Credentials into Upfront Prompt
  - [x] Consolidate Lacerte credentials into `Auth/DatabaseLogin.ahk`:
    - Add Lacerte check (`InStr(app.Name, "Lacerte")`) to `PromptDatabasePasswords(appList)`.
    - Add `Lacerte Email:` and `Lacerte Password:` fields to the upfront modal.
    - Populate `global LacerteEmail` and `global LacertePassword` in-memory.
    - Remove redundant separate `PromptLacerteLogin()` call in `NMGIUpdates.ahk`.
  - [x] Fix Practice CS login automation in `Lib/UpdatePractice.ahk`:
    - Dynamically locate the active login dialog handle via `WinGetList("ahk_exe " practiceExe)` matching visible dialog with Edit and OK controls.
    - Target the password control directly (second edit control / empty edit control) without relying on UIA tree walk or `ES_PASSWORD (0x0020)` style.
    - Focus, click, and inject `PracticePassword` using `SendText` + `ControlSetText`.
    - Click OK button / send `{Enter}` and wait for modal closure (`WinWaitClose`) before awaiting `"Practice CS -"`.
  - [x] Harmonize `Lib/UpdateAccountingCS.ahk` with the same robust login dialog detection (`SubmitCSDatabaseLogin` in `Core/CSConnect.ahk`).
- [x] **Step 4.4g**: Precise Password Field Targeting in `SubmitCSDatabaseLogin` (Fix Open Firm Overwrite)
  - [x] Exclude ComboBox child edit controls: filter out any Edit control where `DllCall("GetParent")` class contains `"COMBOBOX"`.
  - [x] Anchor password box detection to the `"Password:"` static label: match Edit control with `Abs(ey - ly) <= 20` and `ex >= lx + lw`.
  - [x] Auto-recovery if `"Password:"` label is missing (due to corrupted `Open Firm`): do not type into unverified controls; re-select the first valid firm via `CB_SETCURSEL (0x014E)`.
  - [x] Validate via `smoke.ps1` and recompile `NMGIupdates.exe` via `Ahk2Exe.exe`.
  - [x] Atomically commit Step 4.4g.
- [x] **Step 4.4h**: CS Suite Invalid Password / Credential Error Handling
  - [x] Add invalid credential modal popup detection in `Core/CSConnect.ahk` (`SubmitCSDatabaseLogin`):
    - Poll for error dialog containing `"not valid for the Firm"` or `"valid Staff ID and Password"`.
    - Dismiss the error popup (`ControlClick("OK")` / `{Enter}`) and dismiss the login card (`ControlClick("Cancel")` / `{Esc}`).
    - Return standardized status `" - Error (Invalid credentials)"`.
    - Return `" - Error (Login timeout)"` if dashboard wait times out.
  - [x] Propagate `SubmitCSDatabaseLogin` return value in `Lib/UpdateAccountingCS.ahk` and `Lib/UpdatePractice.ahk` to exit cleanly on failure.
  - [x] Validate via `smoke.ps1` and recompile `NMGIupdates.exe` via `Ahk2Exe.exe`.
  - [x] Atomically commit Step 4.4h.
- [x] **Step 4.4i**: Patient Single-Submit Authentication & Multi-Popup Dismissal
  - [x] Single submit action in `Core/CSConnect.ahk` (`SubmitCSDatabaseLogin`): eliminate multi-message rapid-fire submission (`ControlClick` + `BM_CLICK` + `{Enter}`) in favor of a single deliberate submit.
  - [x] Patient validation wait loop: after submitting once, wait up to 45s without re-submitting while SQL database verification completes.
  - [x] Comprehensive multi-popup dismissal (`DismissAllLoginErrors`): poll parent text and child control text across all process and title windows, dismissing any and all cascading error modals.
  - [x] Validate via `smoke.ps1` and recompile `NMGIupdates.exe` via `Ahk2Exe.exe`.
  - [x] Atomically commit Step 4.4i.
- [x] **Step 4.4j**: Display Scanning Tooltip on Initial Launch
  - [x] Show `ToolTip("Scanning applications, please wait...", 100, 100)` immediately on launch when scanning starts.
  - [x] Unconditionally clear `ToolTip()` once `MyGui.Show("NoActivate")` has positioned and displayed the main dashboard window.
  - [x] Validate via `smoke.ps1` and recompile `NMGIupdates.exe` via `Ahk2Exe.exe`.
  - [x] Atomically commit Step 4.4j.
- [x] **Step 4.4k**: Author Comprehensive Technician-Focused GitHub README.md
  - [x] Write `README.md` covering architecture, prerequisites, initial launch/caching, UI features & shortcuts, upfront credential handling, application-specific operational details, troubleshooting, and build instructions.
  - [x] Atomically commit Step 4.4k.
- [x] **Step 4.4l**: QuickBooks Subscription Expired/Expiring Popup Dismissal
  - [x] Implement `DismissQBSubscriptionPopup()` with multi-tiered dismissal (UIA button click, Win32 ControlClick "Close", Button2, Esc keyboard shortcut, geometric client coordinate click, and WinClose fallback).
  - [x] Consolidate startup popup handling into `HandleQBPopups()` on a 500ms `SetTimer` checking for both "Upgrade Internet Explorer" and subscription expiration warnings.
  - [x] Guard main QuickBooks window wait loop against false-positive matching on the subscription dialog (`ExcludeTitle: "subscription"` and explicit dismissal before `WinWait`).
  - [x] Validate via `smoke.ps1`, recompile `NMGIupdates.exe` via `Ahk2Exe.exe`, and test compiled binary.
  - [x] Atomically commit Step 4.4l.
- [x] **Step 4.4m**: Add "Copy Log to Clipboard" Button to Batch Summary Dialog
  - [x] Replace standard `MsgBox` in `ShowSummaryReport(results)` with a dedicated `+AlwaysOnTop` summary dialog.
  - [x] Implement "Copy Log to Clipboard" button that copies the formatted summary report along with today's log entries to `A_Clipboard`, with dynamic button feedback ("Copied to Clipboard!").
  - [x] Add "Close" button and escape / close handlers.
  - [x] Validate via `smoke.ps1`, recompile `NMGIupdates.exe` via `Ahk2Exe.exe`, and test compiled binary.
  - [x] Atomically commit Step 4.4m.
- [x] **Step 4.4n**: Prioritize Fixed Assets \\goserver\Y\ & Y:\ Mapped Locations
  - [x] Prioritize `\\goserver\Y\WinCSI\DSW\dsw.exe` at the top of `potentialPaths` in `Lib/UpdateFixedAssets.ahk`.
  - [x] Add `\\goserver\Y$\WinCSI\DSW\dsw.exe`, `\\goserver\WinCSI\DSW\dsw.exe`, and mapped drive `Y:\WinCSI\DSW\dsw.exe` & `Y:\DSW\dsw.exe`.
  - [x] Adjust `IsHostReachable` default timeout from 300ms to 1000ms in `Core/Network.ahk` to reliably accommodate VPN / WAN latencies.
  - [x] Validate via `smoke.ps1`, recompile `NMGIupdates.exe` via `Ahk2Exe.exe`, and test compiled binary.
  - [x] Atomically commit Step 4.4n.
- [x] **Step 4.4o**: Fix Adobe Acrobat Headless Hang via ShellRun (Standard User Execution)
  - [x] Implement `ShellRun` in `Core/Process.ahk` using Windows Shell COM (`Shell.Application.Windows.Item(SWC_DESKTOP).Document.Application.ShellExecute`) to drop Administrator elevation when launching desktop applications.
  - [x] Update `Lib/UpdateAdobe.ahk` to launch `Acrobat.exe` via `ShellRun` with the proper working directory (`workingDir`), bypassing Adobe Protected Mode / Sandbox elevation deadlocks.
  - [x] Validate via `smoke.ps1`, recompile `NMGIupdates.exe` via `Ahk2Exe.exe`, and test compiled binary.
  - [x] Atomically commit Step 4.4o.
- [x] **Step 4.4p**: Fix Adobe Acrobat Window Detection and Classic UI Menu Navigation
  - [x] Implement multi-criteria window detection (`ahk_class AcrobatSDIWindow`, title `"Adobe Acrobat"`, title `"Acrobat Reader"`, process fallbacks) capturing `adobeHwnd` to eliminate AppContainer / Protected Mode `OpenProcess` detection failures.
  - [x] Use `adobeHwnd` directly for `WinActivate`, foreground enforcement (`SetForegroundWindow`, `BringWindowToTop`), and `WinWaitActive`.
  - [x] Add runtime UI mode detection (Classic UI with MenuBar vs. Modern New Experience UI with Menu button) via UIA element detection on `adobeHwnd`.
  - [x] Correct Classic UI accelerator key sequence to `Alt+H` -> `u` (Check for Updates).
  - [x] Pass `adobeHwnd` directly to `UIA.ElementFromHandle(adobeHwnd)` for fallback menu interaction and eliminate string-based `"ahk_exe Acrobat.exe"` references in `UpdateAdobe.ahk`.
  - [x] Validate via `smoke.ps1`, recompile `NMGIupdates.exe` via `Ahk2Exe.exe`, and test compiled binary.
  - [x] Atomically commit Step 4.4p.
- [x] **Step 4.4q**: Multi-Tiered Adobe Acrobat "Check for Updates" Invocation
  - [x] Default UI mode to Classic (`isClassicUI := true`) unless modern "Menu" button is explicitly detected via UIA.
  - [x] Implement multi-tiered trigger sequence in `Lib/UpdateAdobe.ahk`:
    - Tier 1: `Alt+H` -> `c` -> `{Enter}` (Acrobat DC / Pro 64-bit standard accelerator)
    - Tier 2 (after 2s): `Alt+H` -> `u` -> `{Enter}` (Acrobat 2020 / Reader accelerator)
    - Tier 3 (after 4s): `Alt+H` -> `{Up}` -> `{Enter}` (wrap-around to bottom menu item)
    - Tier 4: `UIA.GetRootElement().FindElement({Name: "(?i)check for updates", mm: "regex"})` across desktop popup menus
  - [x] Validate via `smoke.ps1`, recompile `NMGIupdates.exe` via `Ahk2Exe.exe`, and test compiled binary.
  - [x] Atomically commit Step 4.4q.
- [x] **Step 4.4r**: Prioritize UNC Paths Before Drive Letter Paths Across All Applications
  - [x] Reorder `potentialPaths` in `Lib/UpdateFixedAssets.ahk`: All UNC (`\\...`) paths first, then mapped/local drive letters (`Y:\`, `X:\`, `U:\`, `W:\`, `C:\`).
  - [x] Reorder `potentialPaths` in `Lib/UpdateFPS.ahk`: All UNC (`\\...`) paths first, then drive letters (`F:\`, `W:\`, `X:\`, `P:\`, `S:\`, `T:\`, `C:\`).
  - [x] Reorder `potentialPaths` in `Lib/UpdatePractice.ahk`: All UNC (`\\...`) paths first across production and legacy binaries, then drive letters (`T:\`, `W:\`, `X:\`, etc.).
  - [x] Add UNC network share paths (`\\sql1\...`, `\\wbsql1\...`, `\\app1\...`, `\\agcfsapp1\...`, `\\chfsapp1\...`) to `Lib/UpdateAccountingCS.ahk`, update to `SafeFileExist`, and ensure UNC paths precede drive letters.
  - [x] Verify `Lib/UpdateFileCabinet.ahk` and `Lib/UpdateUT.ahk` to ensure all UNC paths strictly precede drive letter paths.
  - [x] Validate via `smoke.ps1`, recompile `NMGIupdates.exe` via `Ahk2Exe.exe`, and test compiled binary.
  - [x] Atomically commit Step 4.4r.
- [x] **Step 4.4s**: Diagnose & Fix Fixed Assets Path Resolution (`\\app1` vs `C:\` Cache & Network Probe)
  - [x] Investigate why `GUIsettings.ini` still holds `C:\WinCSI\DSW\dsw.exe`: Root cause identified as 64-bit struct offset bug in `Core/Network.ahk` where `ai_addr` was read from offset 24 (`ai_canonname` = 0) instead of offset 32, causing `connect` to fail with WSAEFAULT (10014) and evaluate every UNC host as unreachable, forcing fallback to local `C:\` which was cached in `GUIsettings.ini`.
  - [x] Fix `Core/Network.ahk` (`IsHostReachable`): Updated `ai_addr` offset to `16 + A_PtrSize * 2`, switched `hints` to `AF_UNSPEC (0)`, and dynamically created socket matching `ai_family`, `ai_socktype`, and `ai_protocol`.
  - [x] Verified socket connection via diagnostic test (`reachable: True`, select = 1).
  - [x] Validated via `smoke.ps1`, recompiled `NMGIupdates.exe` via `Ahk2Exe.exe`, and verified compiled binary (`smoke_exe.ps1`).
- [ ] **Step 4.5**: End-to-End Suite Smoke & Packaging (Milestone 4 Wrap-Up)

---

### Milestone 5: Shortcut-First Discovery Engine
*Goal: Rebuild Jacro's application discovery into a 2-tier architecture that searches authoritative desktop shortcuts in C:\Users\Public\Desktop\Applications (and recursive subfolders) before falling back to candidate path lists.*

- [x] **Step 5.1**: Build `Core/ShortcutScanner.ahk`
  - [x] Implement prioritized directory discovery (`C:\Users\Public\Desktop\Applications`, `A_Desktop . "\Applications"`, Public Desktop root, User Desktop root).
  - [x] Implement fast recursive `.lnk` parsing and in-memory indexing (`IndexShortcuts`) with `ExpandEnvVars` support.
  - [x] Implement signature matching (`FindShortcutPath`) with 2-pass prioritization (Applications folder first, then Desktop root) and `SafeFileExist` validation.
  - [x] Provide `ClearShortcutCache()` and wire into `BuildGUI(forceRescan)` in `NMGIUpdates.ahk`.
  - [x] Validate with unit tests and mock recursive nested folder tests.
  - [x] Atomically commit Step 5.1.
- [ ] **Step 5.2**: Wire Shortcut Discovery into Thomson Reuters Modules
  - Update `Lib/UpdateFixedAssets.ahk`, `Lib/UpdateUT.ahk`, `Lib/UpdateFileCabinet.ahk`, `Lib/UpdateAccountingCS.ahk`, `Lib/UpdatePractice.ahk`, `Lib/UpdateFPS.ahk`, `Lib/UpdatePPC.ahk`.
  - Atomically commit Step 5.2.
- [ ] **Step 5.3**: Wire Shortcut Discovery into QuickBooks, Lacerte, Adobe & Browsers
  - Update `Lib/UpdateQB.ahk`, `Lib/UpdateLacerte.ahk`, `Lib/UpdateAdobe.ahk`, `Lib/UpdateChrome.ahk`, `Lib/UpdateEdge.ahk`, `Lib/UpdateFirefox.ahk`.
  - Atomically commit Step 5.3.
- [ ] **Step 5.4**: Authoritative Shortcut Synchronization in `Core/Config.ahk` & Dashboard Integration
  - Update `ResolveAppPath` to synchronize with authoritative desktop shortcuts.
  - Wire `ClearShortcutCache()` into `ClearHostCache()` and `btnRescan`.
  - Atomically commit Step 5.4.
- [ ] **Step 5.5**: End-to-End Verification, Documentation & Release
  - Atomically commit Step 5.5.


