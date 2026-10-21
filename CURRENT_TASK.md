# Current Task Tracker: Modernizing Jacro Architecture

## Status
- **Current Phase**: Milestone 3 (Interface Standardization & Error Resilience)
- **Active Step**: Step 3.2 Complete. Ready for Step 3.3 (Hardening Status & Recovery Logic).
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
- [ ] **Step 3.3**: Hardening Status & Recovery Logic
  - Unify timeout and kill routines across all modules.
  - Provide a summary report modal upon completion of batch updates.
- [ ] **Step 3.4**: Final Verification & Documentation Update
  - Test end-to-end launch on test machine.
  - Update `CHANGELOG.md` with transition notes.
