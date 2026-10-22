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
- **Shortcut-First Application Discovery Engine**: Rebuilt Jacro's path discovery into a 2-tier architecture that searches authoritative desktop shortcuts before falling back to manual candidate path lists:
  - Extracted `Core/ShortcutScanner.ahk` implementing fast recursive shortcut discovery across `C:\Users\Public\Desktop\Applications` (and all nested subfolders: `Tax`, `Accounting`, etc.) as well as user Desktop roots.
  - Implemented in-memory caching (`ShortcutCache`) and native `FileGetShortcut` target extraction with environment variable expansion (`ExpandEnvironmentStrings`).
  - Added two-pass signature evaluation (`FindShortcutPath`) prioritizing shortcuts in `Applications` folders before root desktop links, and validating physical reachability with `SafeFileExist`.
  - Added application-level matching rules (`FindAppShortcut`) across all 22 registered applications in Jacro.
  - Updated all 11 application updater modules (`UpdateFixedAssets.ahk`, `UpdateUT.ahk`, `UpdateFileCabinet.ahk`, `UpdateAccountingCS.ahk`, `UpdatePractice.ahk`, `UpdateFPS.ahk`, `UpdatePPC.ahk`, `UpdateQB.ahk`, `UpdateLacerte.ahk`, `UpdateAdobe.ahk`, `UpdateChrome.ahk`, `UpdateEdge.ahk`, `UpdateFirefox.ahk`) to check authoritative desktop shortcuts first before falling back to manual candidate paths.
  - Updated `Core/Config.ahk` (`ResolveAppPath`) to automatically synchronize `GUIsettings.ini` whenever an authoritative desktop shortcut points to a different location than previously cached, eliminating the multi-installation path dilemma.
  - Wired `ClearShortcutCache()` into `BuildGUI(forceRescan)` in `NMGIUpdates.ahk`.
- **QuickBooks Subscription Expired/Expiring Dismissal**: Added `DismissQBSubscriptionPopup` and `HandleQBPopups` in `Lib/UpdateQB.ahk` with multi-tiered dismissal (UIA button click, Win32 ControlClick "Close", Button2, Esc, proportional coordinate click, and WinClose). Replaced blind `WinWait` with an active polling loop that filters out subscription dialogs and captures `mainHwnd`, allowing QuickBooks to launch and update smoothly even when subscription expiration warnings are displayed.
- **Discovery Source Tracking & Dashboard Hover Tooltips**: Added discovery provenance tracking across the shortcut-first discovery engine:
  - Extended `Core/ShortcutScanner.ahk` with `FindShortcutInfo` and `FindAppShortcutInfo` returning rich metadata objects (`{ Target, LnkPath, LnkName, IsApplicationsFolder }`).
  - Updated `ResolveAppPath` in `Core/Config.ahk` to persist discovery origins to `[PathSources]` in `GUIsettings.ini` (`Shortcut: <lnk>` vs `FallbackScan` vs `NotInstalled`) and assign `app.Source` in memory.
  - Implemented `WM_MOUSEMOVE (0x0200)` and periodic `CheckHoverLeave` hover tooltips in `NMGIUpdates.ahk` mapped to application checkbox (`app.cb.Hwnd`) and label (`app.txt.Hwnd`) controls. Hovering over any application control displays application name, resolved path, and discovery origin. Moving the cursor off controls immediately dismisses the tooltip.
  - Strict Isolation: Discovery source information is strictly confined to `GUIsettings.ini` and hover tooltips, preserving the pristine format of the daily audit log (`yyMMdd-Update.log`) and summary modal report.
- **MSI Advertised Shortcut Resolution**: Enhanced `Core/ShortcutScanner.ahk` with dual-tier Windows Installer resolution (`ResolveAdvertisedShortcut`) using `WindowsInstaller.Installer` COM Automation and Win32 `msi.dll` APIs (`MsiGetShortcutTargetW` and `MsiGetComponentPathW`). Automatically resolves target executable paths for Windows Installer Advertised Shortcuts (e.g., Practice CS, UltraTax, and CS Professional Suite shortcuts where the `.lnk` target field is greyed out and standard `FileGetShortcut` returns empty), ensuring seamless out-of-the-box shortcut discovery on all client workstations without manual intervention.
- **Robust Advertised Shortcut Detection & Stubs**: Enhanced advertised shortcut handling to intercept Windows Installer stub executables (`C:\Windows\Installer\{GUID}\...exe`), resolve real binary paths via `ComponentPath`, and search extended desktop roots (`A_DesktopCommon`, `C:\Users\%A_UserName%\Desktop`). If an advertised shortcut is detected on the desktop but its target path is unresolvable via MSI, automatically pairs the shortcut with the validated candidate path from `pathFn()` so the discovery source is correctly recognized as `Shortcut: <lnk>` rather than reverting to `FallbackScan`.

### Changed
- Renamed main entry point `CheckboxGUItest.ahk` to `NMGIUpdates.ahk` reflecting production readiness.
- Changed application scanning feedback to display the "Scanning applications, please wait..." ToolTip immediately upon initial launch, clearing it automatically once the main GUI is displayed.
- Moved dormant `UpdateAdobe.ahk` and `UpdateFPS.ahk` from `Lib/` to `archive/` pending modernization.
- Reorganized application candidate fallback path lists across all Thomson Reuters modules (`UpdateFixedAssets.ahk`, `UpdateAccountingCS.ahk`, `UpdatePractice.ahk`, `UpdateUT.ahk`, `UpdateFileCabinet.ahk`, `UpdateFPS.ahk`) so that local drive paths (`C:\`) are evaluated first, followed by mapped network drive letters in alphabetical order, and lastly UNC network shares (`\\...`) in alphabetical order. With authoritative desktop shortcuts taking Priority 1 via the Shortcut-First discovery engine, prioritizing local and mapped drive paths in the candidate list speeds up fallback scanning and prevents unintended UNC fallbacks when shortcuts are absent.
- Prioritized `\\goserver\Y\WinCSI\DSW\dsw.exe` and added associated `Y:\` mapped and UNC share variants in `Lib/UpdateFixedAssets.ahk`. Adjusted `IsHostReachable` default timeout from 300ms to 1000ms in `Core/Network.ahk` to accommodate WAN/VPN network conditions.
- Standardized return signatures across all active `Lib/Update*.ahk` modules to use uniform status prefixes (`" - Updates installed"`, `" - No updates"`, `" - Updates available (Manual)"`, `" - Error (<Reason>)"`).
- Replaced repetitive process kill logic across `UpdateChrome.ahk`, `UpdateEdge.ahk`, `UpdateFirefox.ahk`, and `UpdateQB.ahk` with `Core/Process.ahk` helpers.
- Wrapped UNC lookups in `UpdateUT.ahk`, `UpdateFixedAssets.ahk`, `UpdateFileCabinet.ahk`, and `Core/Config.ahk` with `SafeFileExist()` to eliminate 25–30s Windows SMB redirector freezes when disconnected from client networks or VPNs.

- Fixed QuickBooks duplicate launch and added empty window popup dismissal in `Lib/UpdateQB.ahk`: Eliminated duplicate `Run(qbPath)` call that triggered QuickBooks's internal guard dialog ("An empty QuickBooks window already exists, so QuickBooks will use that window"). Added `DismissQBEmptyWindowPopup()` to automatically acknowledge the popup with OK / Enter, excluded it from main window title matching, and enhanced `KillQBTasks()` to forcefully sweep lingering `QBW32.exe` and `QBW.exe` instances before launching.
- Fixed unassigned variable crash (`loginHwnd`) and added blank database password support in `Core/CSConnect.ahk` (`SubmitCSDatabaseLogin`): Corrected local scoping of `loginHwnd := 0` and removed the non-blank password guard so databases configured without passwords (blank passwords) properly detect the CS Professional Suite login card, ensure the password field is clear, and submit (click OK / send Enter) to log in cleanly. Guarded ComboBox text matching to prevent empty strings from falsely triggering dropdown auto-recovery.
- Fixed 64-bit Winsock `getaddrinfo` structure offset and address family mismatch in `Core/Network.ahk` (`IsHostReachable`): Corrected `ai_addr` pointer offset calculation from `16 + A_PtrSize` (offset 24 on x64, which incorrectly pointed to `ai_canonname` and evaluated to NULL `0`) to `16 + A_PtrSize * 2` (offset 32 on x64, pointing to valid `sockaddr`). Switched `hints` to `AF_UNSPEC (0)` and dynamically created socket with `ai_family`, `ai_socktype`, and `ai_protocol` from `res`, enabling reliable resolution of IPv4/IPv6 single-label hosts like `\\app1` and restoring full UNC reachability checking across all modules.
- Fixed Adobe Acrobat "Check for Updates" trigger in Classic DC UI by defaulting UI mode to Classic (`isClassicUI := true`) and implementing a multi-tiered invocation sequence: Tier 1 sends `Alt+H` -> `c` -> `{Enter}` (Acrobat DC 64-bit standard accelerator), Tier 2 falls back to `Alt+H` -> `u` -> `{Enter}` (Acrobat 2020 / Reader), Tier 3 navigates via `Alt+H` -> `{Up}` -> `{Enter}` (wrap-around to bottom menu item), and Tier 4 performs desktop-wide UIA search for `(?i)check for updates`.
- Fixed Adobe Acrobat window detection hang where `WinWait("ahk_exe Acrobat.exe")` failed to detect the open Acrobat window because Protected Mode / AppContainer process query permissions restricted `OpenProcess`. Added multi-criteria window detection (`ahk_class AcrobatSDIWindow`, title `"Adobe Acrobat"`, `"Acrobat Reader"`) capturing the exact `adobeHwnd`.
- Fixed Adobe Acrobat headless process hang where Acrobat spawned multiple background processes without rendering a window when launched from elevated administrator context. Added `ShellRun` in `Core/Process.ahk` to drop elevation via the Windows desktop shell COM interface (`Shell.Application`) and launch Acrobat at standard user integrity with proper working directory, resolving Protected Mode sandbox deadlocks.
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
