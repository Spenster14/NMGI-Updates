# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - 2026-10-21
### Added
- **Core Modularization**: Extracted core infrastructure into dedicated `Core/` modules:
  - `Core/AppRegistry.ahk`: Declarative application table (`Apps`), priority category assignment, and sorting algorithms.
  - `Core/Config.ahk`: Decoupled INI cache reader/writer (`ResolveAppPath`) operating strictly against `GUIsettings.ini [Paths]`.
  - `Core/Logger.ahk`: Universal update log writer (`UpdateLog`), status lookup (`GetAppStatus`), and font color mapping (`GetColorByStatus`).
  - `Core/Network.ahk`: Fast Win32 Winsock (`ws2_32`) non-blocking TCP reachability checks (`IsHostReachable`) with per-session caching (`HostCache`) and safe UNC file guards (`SafeFileExist`).
  - `Core/Process.ahk`: Unified graceful process termination (`TerminateProcessGracefully`) with window messaging, process wait timeouts, and forceful taskkill fallbacks, plus WMI wildcard process cleanup (`KillProcessesByPrefix`).
- **Auth Service Decoupling**: Extracted authentication dialogs and popup handlers into `Auth/`:
  - `Auth/Bulletins.ahk`: Centralized startup bulletin and popup dismissal (`HandleBulletins`).
  - `Auth/TRLogin.ahk`: Unified Thomson Reuters upfront credentials modal and window handlers (`TRLogin`, `CloseSignInTR`).
  - `Auth/LacerteLogin.ahk`: Upfront Lacerte operator credential collection modal (`PromptLacerteLogin`).
- **Unified Upfront Credentials**: Consolidated Lacerte authentication (`LacerteEmail`, `LacertePassword`) into `Auth/DatabaseLogin.ahk` (`PromptDatabasePasswords`), providing a single upfront credentials modal for all selected password-requiring applications (Accounting CS, Practice CS, FPS, Lacerte) and eliminating sequential secondary popups.
- **CS Suite Database Login Automation**: Added shared `SubmitCSDatabaseLogin(winPrefix, exeName, dbPassword)` in `Core/CSConnect.ahk` to reliably detect and inject database passwords on borderless WinForms login dialogs without freezing or slow cross-process UIA tree walks, resolving the Practice CS login hang.
- **Precise CS Password Field Targeting**: Excluded ComboBox child edit controls (`Open Firm`, `Staff ID`) from password injection via Win32 parent class inspection (`GetParent`), and anchored password box detection to the `"Password:"` static label row, preventing accidental overwriting of firm names. Added auto-recovery logic to re-select valid firms via `CB_SETCURSEL` if `Open Firm` was previously corrupted.
- **CS Suite Patient Single-Submit & Multi-Popup Dismissal**: Refactored `SubmitCSDatabaseLogin` in `Core/CSConnect.ahk` to perform a single deliberate submission and enter a dedicated 45s database verification loop, eliminating rapid-fire multi-clicks (`ControlClick` + `BM_CLICK` + `Enter`) and repeated loop smashing that caused stacked error popups. Added recursive multi-popup dismissal (`DismissAllLoginErrors`) that inspects both parent and child `WindowsForms10.STATIC` text and closes all cascading warning dialogs cleanly.
- **Batch Completion Summary**: Added `ShowSummaryReport(results)` to `NMGIUpdates.ahk`, displaying a clean categorized report modal with counts and itemized breakdowns of Updated, Already Current, Attention Required, and Error states upon batch completion.
- **Summary Dialog Clipboard Copy**: Upgraded `ShowSummaryReport` from a standard OS MsgBox to a dedicated modal dialog with a "Copy Log to Clipboard" button (`&Copy Log to Clipboard` / `Alt+C`), copying the structured summary breakdown along with raw daily log entries to the clipboard with visual button confirmation.
- **QuickBooks Subscription Expired/Expiring Dismissal**: Added `DismissQBSubscriptionPopup` and `HandleQBPopups` in `Lib/UpdateQB.ahk` with multi-tiered dismissal (UIA button click, Win32 ControlClick "Close", Button2, Esc, proportional coordinate click, and WinClose). Replaced blind `WinWait` with an active polling loop that filters out subscription dialogs and captures `mainHwnd`, allowing QuickBooks to launch and update smoothly even when subscription expiration warnings are displayed.

### Changed
- Renamed main entry point `CheckboxGUItest.ahk` to `NMGIUpdates.ahk` reflecting production readiness.
- Changed application scanning feedback to display the "Scanning applications, please wait..." ToolTip immediately upon initial launch, clearing it automatically once the main GUI is displayed.
- Moved dormant `UpdateAdobe.ahk` and `UpdateFPS.ahk` from `Lib/` to `archive/` pending modernization.
- Added `UpdateUT.ahk` / `UpdateFixedAssets.ahk` network locations (`\\wbsql1`, `\\agcfsapp1`).
- Prioritized `\\goserver\Y\WinCSI\DSW\dsw.exe` and added associated `Y:\` mapped and UNC share variants in `Lib/UpdateFixedAssets.ahk`. Adjusted `IsHostReachable` default timeout from 300ms to 1000ms in `Core/Network.ahk` to accommodate WAN/VPN network conditions.
- Standardized return signatures across all active `Lib/Update*.ahk` modules to use uniform status prefixes (`" - Updates installed"`, `" - No updates"`, `" - Updates available (Manual)"`, `" - Error (<Reason>)"`).
- Replaced repetitive process kill logic across `UpdateChrome.ahk`, `UpdateEdge.ahk`, `UpdateFirefox.ahk`, and `UpdateQB.ahk` with `Core/Process.ahk` helpers.
- Wrapped UNC lookups in `UpdateUT.ahk`, `UpdateFixedAssets.ahk`, `UpdateFileCabinet.ahk`, and `Core/Config.ahk` with `SafeFileExist()` to eliminate 25–30s Windows SMB redirector freezes when disconnected from client networks or VPNs.

### Fixed
- Fixed Lacerte double-logging bug where `UpdateLacerte.ahk` wrote directly to `TodayDate-Update.log` via `FileAppend` in addition to `UpdateLog()` in `Core/Logger.ahk`.
- Fixed batch execution aborts in `UpdateQB.ahk` by replacing abrupt `ExitApp` calls on missing paths/configurations with graceful error return strings.
- Removed duplicate `#Requires AutoHotkey v2.0` directives.

### Removed
- Stopped tracking compiled `.exe` binaries and per-machine `GUIsettings.ini` cache in Git (added to `.gitignore`).
- Deleted legacy prototype `GUITest.ahk` and scratch scripts (`GetDomain.ahk`, `TestChrome.ahk`, `connectwise.ahk`, `test_cb.ahk`, `test_cb2.ahk`).
- Deleted unused external library `Lib/FindText.ahk`, legacy OCR backups, and UIA dump scripts.
- Stripped over 600 lines of dead commented-out legacy code blocks across `Lib/Update*.ahk` and `Core/Logger.ahk`.


## [Unreleased] - 2026-10-01
### Added
- Completely refactored the GUI in `CheckboxGUItest.ahk` to dynamically sort and display only installed applications.
- Added a "Launching [product]..." status update immediately before an application starts its update cycle, resolving an issue where the Status Box would appear idle while waiting for heavy applications to load.
- Added a new `UpdateLacerte.ahk` submodule to support Lacerte updates (dynamically supporting years 2022, 2023, and 2024). It is sorted natively into the QuickBooks/Category-2 group, features an upfront email/password authentication GUI that prompts immediately when "Start" is clicked, and supports alternative Lacerte launchers (`w[XX]tax-launcher.exe`).
- Added a universal process wait (`ProcessWaitClose`) to the main GUI execution loop to guarantee that slow-closing applications (like FileCabinet) are completely purged from memory before the next application is allowed to launch.
- Implemented a category-based sorting system for the GUI list (Thomson Reuters -> QuickBooks -> Others -> Browsers) with alphabetical sorting within each category.
- Added color-coding to GUI text (Green for updated, Purple for no updates, Red for errors) based on previous log runs.
- Replaced system-wide ToolTips with a dedicated `StatusBox` Edit control inside the GUI for cleaner progress tracking.
- Added a `Shift + Right-Click` shortcut to the `StatusBox` that instantly unchecks all successfully processed applications (Green/Light Gray), leaving only unprocessed or failed (Red) items checked.
- Added a flashing text effect to highlight the application currently being updated.
- Implemented `GUIsettings.ini` to cache application file paths, dramatically reducing the GUI load time from ~10 seconds to near-instant.
- Added a "Rescan" button to force-recheck application paths and refresh the INI cache.
- Set the GUI to `+AlwaysOnTop` and automatically positioned it in the bottom right corner of the primary display.

### Changed
- Changed the 'NotUpdated' font color from Dark Gray to a much lighter, softer Silver/Light Gray (`#A0A0A0`) to visually fade out software that has been fully processed and requires no attention.
- Flattened the `potentialPaths` arrays in `UpdateFixedAssets.ahk` and `UpdateFileCabinet.ahk` and completely removed slow WMI domain checks.
- Unified `UpdateStatus()` function calls across all `Update*.ahk` library files.
- Redesigned the Thomson Reuters login flow (`TRLogin()`) to prompt the user for all credentials (Email, Password, and MFA Code) upfront in a single GUI window, rather than pausing the automation to ask for them sequentially as each screen appears.

### Fixed
- Fixed a UIA framework crash (`0x80131509 InvalidOperationException`) during Lacerte login by converting backend `.Value` text injections to physical mouse clicks (`Click("left")`) and emulated keystrokes against explicitly targeted `AutomationIds` (`userIdTextBox` and `passwordTextBox`).
- Fixed log parsing bug where apps returning `" - No updates"` were not triggering the Purple "NotUpdated" color because the GUI was checking for `" - No updates found"`.
- Fixed arrow function definitions `(*) =>` in the GUI's `Apps` array to prevent "Too many parameters passed" errors caused by AutoHotkey v2 implicitly passing `this`.
- Removed invalid `mt` margin option in the `CheckboxGUItest.ahk` GUI setup.
- Bypassed a Windows limitation where standard checkbox font colors could not be dynamically changed; replaced checkbox text with a linked native Text control to properly display update status colors (Dark Gray for no updates, Deep Green and Bold for updated, Red for errors, Orange for active) and flashing.
- Fixed GUI startup positioning bugs (including multi-monitor indexing and high-DPI scaling offsets) that caused the right side of the window to clip off-screen. This was achieved by transitioning from logical pixels to physical pixels for window coordinate tracking.
- Fixed a layout bug in the GUI where multi-column Checkboxes were incorrectly stacking at the bottom of the first column instead of filling out their respective columns due to improper Section anchoring.
- Fixed a vertical layout overlapping bug where the Status Box would visually clip into the bottom of the first application column if the third column was shorter.
- Fixed a text clipping bug where dynamically bolded application names would overflow their original control bounding boxes. (Also reduced excessive padding between checkboxes and labels, and expanded the Status Box width to fill the GUI).


## [Unreleased] - 2026-09-10
### Fixed
- Fixed a bug in `UpdateFirefox.ahk` where it would hang on the "About Mozilla Firefox" window because the "Restart to update Firefox" button had a lowercase "u", but the script was searching for a capitalized "Update".
- Fixed a bug in `UpdateFixedAssets.ahk` where it would fail to click the "Restart Fixed Assets CS" popup because Thomson Reuters actually named the popup "UltraTax CS".
- Fixed `PostUpdate` logic in `UpdateFixedAssets.ahk`, `UpdateFileCabinet.ahk`, and `UpdateAccountingCS.ahk` to properly respect the flag and prevent redundant application launches and logins during post-update verification.
- Added `ProcessWaitClose` by capturing the specific PID prior to closing or restarting in `UpdateFixedAssets.ahk`, `UpdateFileCabinet.ahk`, `UpdateChrome.ahk`, `UpdateFirefox.ahk`, and `UpdateEdge.ahk` to ensure the current process completely closes before moving forward.

## [2026-06-18]
### Added
- Added `\\przfsapp1` network location to the paths checked for UltraTax updates in `UpdateUT.ahk`.
- Fixed a bug in `UpdateUT.ahk` where the script could hang indefinitely waiting for a "Restart Required" popup that never appeared. Added timeouts so it gracefully closes manually if no popup is detected.
- Created this CHANGELOG.md file to start tracking project changes.

### Fixed
- Fixed a COM timeout error (`0x80131505`) in `UpdateQB.ahk` when launching QuickBooks by wrapping `UIA.ElementFromHandle` in a retry loop.
- Moved `AccountingCS` update to be the first application processed in `CheckboxGUItest.ahk` since it requires manual login credentials upfront.
- Corrected a bug in the `taskkill` fallback logic for all three browsers (`UpdateFirefox.ahk`, `UpdateChrome.ahk`, `UpdateEdge.ahk`). `ProcessWaitClose` in AHK v2 returns the PID (which evaluates to True) on a timeout, meaning the `!ProcessWaitClose` condition was skipping the taskkill entirely. Replaced with explicit `ProcessExist` checks to ensure the browsers are forcefully closed if they hang.

## [2026-06-11]
### Changed
- Added an exception to skip the `\\swtho1` network path for UltraTax 2023 updates in `UpdateUT.ahk`, allowing it to fall back to the C drive.
- Commented out automatic update installation for Accounting CS in `UpdateAccountingCS.ahk`; it will now close the Call Summary, explicitly click "No" on the "Apply Updates" popup, close the app, and log "Update found, install manually".
- Updated various AutoHotkey scripts: `GUITest.ahk`, `UpdateAccountingCS.ahk`, `UpdateFileCabinet.ahk`, `UpdateUT.ahk`, `UpdateFixedAssets.ahk`, `CheckboxGUItest.ahk`, `UpdateQB.ahk`, `UIA.ahk`.
- Recompiled executables: `NMGIupdates.exe` and `CheckboxGUItest.exe`.
