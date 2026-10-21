# Current Task Tracker: Modernizing Jacro Architecture

## Status
- **Current Phase**: Planning & Foundation Complete (Transition Specification Established)
- **Active Step**: Awaiting user approval to begin Milestone 1 (Repository Hygiene & Dead Code Retirement).
- **Rule Constraints**: Do not edit functional code until explicitly directed. Maintain atomic steps.

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

- [ ] **Step 2.1**: Declarative Application Registry
  - Extract the application definition list (`Apps` array and category sorter) into a standalone configuration table/class (`src/Core/AppRegistry.ahk`).
  - Decouple the GUI layout rendering from individual application definitions.
- [ ] **Step 2.2**: Centralize Shared Authentication & Dialog Services
  - Extract Thomson Reuters login orchestration (`TRLogin`, `CloseSignInTR`) into `src/Auth/TRLogin.ahk`.
  - Extract Lacerte upfront authentication modal into `src/Auth/LacerteLogin.ahk`.
  - Extract bulletin and startup popup handlers (`HandleBulletins`) into `src/Auth/Bulletins.ahk`.
- [ ] **Step 2.3**: Common Utilities & State Logging
  - Extract log engine (`UpdateLog`, `GetAppStatus`, `GetColorByStatus`) into a dedicated `Logger.ahk` service.
  - Consolidate universal process teardown and polling logic (`ProcessWaitClose` with timeout fallbacks) into a helper.
- [ ] **Step 2.4**: INI Cache Decoupling
  - Refactor `GUIsettings.ini` usage to drop legacy domain pipe mappings and standardize strictly on the `[Paths]` cache.

---

### Milestone 3: Interface Standardization & Error Resilience
*Goal: Standardize the updater module contract across all applications and harden network/UI edge cases.*

- [ ] **Step 3.1**: Standardize Module Return Types & Signatures
  - Standardize all `Update*.ahk` functions to adhere to a uniform signature and typed return structure (e.g. `{ Status: "Updated"|"NoUpdates"|"Error", Message: "..." }`).
  - Strip redundant commented-out legacy blocks across all updater modules.
- [ ] **Step 3.2**: Network UNC Reachability Guards
  - Implement fast network reachability pre-checks for UNC shares (`\\wbsql1`, `\\chfsapp1`, `\\tho1`, `\\agcfsapp1`, `\\przfsapp1`) to prevent lengthy OS-level timeouts when running offline or on disconnected client networks.
- [ ] **Step 3.3**: Hardening Status & Recovery Logic
  - Unify timeout and kill routines across all modules.
  - Provide a summary report modal upon completion of batch updates.
- [ ] **Step 3.4**: Final Verification & Documentation Update
  - Test end-to-end launch on test machine.
  - Update `CHANGELOG.md` with transition notes.
