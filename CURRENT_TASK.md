# Current Task Tracker: Modernizing Jacro Architecture

## Status
- **Current Phase**: Module Expansion (Milestone 4)
- **Active Step**: Step 4.3c complete (FPS highlighting, Web Registration dismissal, and Category 0 priority ordering verified). Ready for Step 4.4: End-to-End Suite Smoke & Packaging.
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
  - [x] Atomically commit Step 4.3c.




