# Changelog

All notable changes to this project will be documented in this file.

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
