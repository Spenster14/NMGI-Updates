# Project Specification: Jacro (NMGI-Updates)

## 1. Executive Summary & Core Product Goal

**Jacro (NMGI-Updates)** is an automated client-maintenance and software-update orchestration system developed for **NMGI** (Managed IT Services / MSP) to support CPA and accounting firms. 

The primary goal of Jacro is to automate the discovery, launching, update checking, patching, credential handling, and post-update verification of complex desktop tax, accounting, and productivity software across heterogeneous client workstations and remote desktop/application servers.

### Target Workflows
1. **Dynamic Environment Discovery**:
   - Detect installed business applications across local drives (`C:`) and firm-specific mapped or UNC network shares (e.g., `W:`, `X:`, `\\wbsql1\WINCSI$`, `\\tho1\thomson\WINCSI`, `\\agcfsapp1\WinCSI`).
   - Cache resolved paths in `GUIsettings.ini` to guarantee near-instant GUI initialization on subsequent launches while providing on-demand rescan capabilities.
2. **Interactive Orchestration Dashboard**:
   - Present a lightweight, non-intrusive, `+AlwaysOnTop` multi-column desktop interface docked to the work area.
   - Categorize applications logically (Thomson Reuters Suite $\rightarrow$ Intuit Accounting/Tax $\rightarrow$ Productivity $\rightarrow$ Browsers).
   - Display real-time status and visual indicators (color-coded text: Green for updated, Light Gray for no updates needed, Red for attention/errors, Orange pulsing for active execution).
   - Provide bulk-selection and quick filters (e.g., `Shift + Right-Click` to uncheck processed applications).
3. **Automated GUI Patching & Modal Negotiation**:
   - Launch and attach to target processes via Microsoft UI Automation (UIA v2) and robust keyboard fallbacks.
   - Handle upfront centralized credential prompts (single modal for Thomson Reuters Email, Password, and MFA; Intuit Lacerte authentication) rather than blocking mid-run.
   - Suppress, dismiss, or navigate startup popups, bulletins, splash screens, and modal dialogs (e.g., "Choose Data Location", "User Bulletin", "User already present", "Onvio").
   - Trigger vendor update engines (CS Connect / Call Now, Intuit update services, browser help/about endpoints).
   - Discern terminal update states ("No new updates", "Updates applied / restart required", "Users currently in application", "Manual intervention required").
   - Handle application relaunch cycles and post-update sanity checks.
4. **Standardized Status & Audit Logging**:
   - Log execution records to `yyMMdd-Update.log` with standardized result strings.
   - Provide clean summary progress in the dedicated GUI status control without relying on OS-level tooltips.

---

## 2. Codebase Audit: Active Modules vs. Dead/Redundant Code

### Active Core Production Files
| File | Role / Purpose | Status / Notes |
| :--- | :--- | :--- |
| `NMGIUpdates.ahk` | **Main Application Entry Point** | Fully functional (renamed from `CheckboxGUItest.ahk` in Milestone 1). Contains the modern Jacro GUI (`Jacro v261008`), path caching, sorting, execution loop, TR login flow, bulletin management, and log engine. |
| `Lib/UpdateUT.ahk` | Thomson Reuters UltraTax CS Updater | Active & battle-tested. Supports versions 23, 24, 25 across multiple UNC/local paths. Handles CS Connect, Call Summary parsing, and restart prompts. |
| `Lib/UpdateFixedAssets.ahk` | Thomson Reuters Fixed Assets CS Updater | Active & battle-tested. Navigates `dsw.exe`, CS Connect, and handles UltraTax-named restart dialogs. |
| `Lib/UpdateFileCabinet.ahk` | Thomson Reuters FileCabinet CS Updater | Active & battle-tested. Handles `fcab.exe`, CS Connect ("Call Now"), pending updates, and active-user lock detection. |
| `Lib/UpdateAccountingCS.ahk` | Thomson Reuters Accounting CS Updater | Active. Navigates `AccountingCS.exe`, CS Connect; currently sets updates to "install manually" to avoid disruptive uncoordinated firm-wide database updates. |
| `Lib/UpdatePractice.ahk` | Thomson Reuters Practice CS Updater | Active. Navigates `PracticeCS.exe`, CS Connect; checks for updates and defers installation manually to avoid firm-wide database locks. Positioned upfront in queue. |
| `Lib/UpdateFPS.ahk` | Thomson Reuters FPS / FAS | Active. Navigates `FAS.EXE -r`, handles user password modal, dismisses client dialog, and inspects Web Updates version matching. Positioned first in queue. |
| `Lib/UpdatePPC.ahk` | Thomson Reuters PPC Tools Installer | Active. Navigates `PPCWebMultiSelect.exe`, advances past installation type, inspects tree checkboxes for pending product updates, and dismisses installer. |
| `Lib/UpdateAdobe.ahk` | Adobe Acrobat Updater | Active. Multi-version path discovery (DC & 2020), UI mode detection (New Experience vs Classic DC vs 2020), and sub-350ms unlicensed trial screen bypass. |
| `Lib/UpdateQB.ahk` | Intuit QuickBooks Desktop Updater | Active. Comprehensive configuration for Enterprise, Premier, and Pro (versions 21–24). Suppresses welcome screen via `QBWUSER.INI`, handles installer prompts, and inspects `Install.log`. |
| `Lib/UpdateLacerte.ahk` | Intuit Lacerte Tax Updater | Active. Supports tax years 22, 23, and 24. Features upfront credential input with keyboard-navigation fallback for WPF controls, Delphi menu automation, and WPF class regex matching. |
| `Lib/UpdateChrome.ahk` | Google Chrome Updater | Active. Cleans up existing processes, opens `chrome://settings/help`, detects update status via UIA, and handles relaunch cycles. |
| `Lib/UpdateEdge.ahk` | Microsoft Edge Updater | Active. Cleans up existing instances, opens `edge://settings/help`, handles "Updates are underway", relaunch, and up-to-date detection. |
| `Lib/UpdateFirefox.ahk` | Mozilla Firefox Updater | Active. Cleans up stale processes, navigates to "About Mozilla Firefox", handles downloading, applying, and restart button clicks. |
| `Lib/UIA.ahk` | UIAutomation Library for AHK v2 | Core Dependency. Descolada's UIA v2 wrapper; foundation for all window/control automation. |
| `Lib/UIA_Browser.ahk` | UIA Browser Extension | Core Dependency. Complement to `UIA.ahk` for browser tree traversal. |
| `Lib/OCR.ahk` | Windows Media OCR Library for AHK v2 | **Active Dependency**. Descolada's UWP OCR wrapper. Strictly required by `UpdateQB.ahk` (`OCR.FromRect`) to monitor QuickBooks Desktop's custom-painted update progress bar and status text, which does not expose accessible UIA elements. |

### Dead, Deprecated, and Redundant Code
> **Status (Milestone 1 complete):** The items below were removed, untracked, or archived. `UpdateAdobe.ahk` and `UpdateFPS.ahk` now live in `archive/` pending modernization. The table is kept as an audit record.
| File / Artifact | Classification | Rationale & Recommendation |
| :--- | :--- | :--- |
| `GUITest.ahk` | **Obsolete Prototype** | Legacy prototype using a single-column ListView, slow WMI domain checks (`GetDomainName`), and pipe-delimited client configs. Superseded by `CheckboxGUItest.ahk`. **Retire / Archive.** |
| `GetDomain.ahk` | **Redundant Utility** | Standalone script that queries WMI domain and copies to clipboard. Domain filtering was removed in favor of direct executable scanning. **Retire / Archive.** |
| `connectwise.ahk` | **Orphaned Scratch Script** | 7-line snippet for ConnectWise Manage time entry; completely unrelated to update automation. **Remove.** |
| `TestChrome.ahk` | **Orphaned Scratch Script** | Early exploratory script for Chrome UIA testing. **Remove.** |
| `test_cb.ahk` & `test_cb2.ahk` | **Scratch Test Scripts** | Temporary GUI checkbox styling and section layout test scripts. **Remove.** |
| `Lib/PreChange250904UpdateEdge.ahk` | **Dead Backup** | Obsolete OCR-based Edge updater snapshot from 2025. **Remove.** |
| `Lib/Preupdate250904UpdateChrome.ahk` | **Dead Backup** | Obsolete OCR-based Chrome updater snapshot from 2025. **Remove.** |
| `Lib/DumpACS.ahk` | **One-off Diagnostic** | Scratch helper to dump Accounting CS UIA tree to file. **Move to tools/debug or remove.** |
| `Lib/DumpFirefoxUIA.ahk` | **One-off Diagnostic** | Scratch helper to dump Firefox UIA tree to file. **Move to tools/debug or remove.** |
| `Lib/UpdateAdobe.ahk` | **Incomplete / Dormant** | Commented out in main app. Hardcoded to legacy domain check (`greenwoodcpa.com`), relies on outdated Acrobat paths, incomplete update handling. **Quarantine or Refactor.** |
| `Lib/UpdateFPS.ahk` | **Broken / Dormant** | Commented out in main app. Contains broken copy-paste of Fixed Assets code and an early exit (`If (1=1) return`). **Quarantine or Remove.** |
| `Lib/FindText.ahk` | **Dead Dependency** | 126 KB screen-scraping library. Zero active references across the entire codebase. **Remove.** |
| `*.exe` (in repo root) | **Tracked Compiled Binaries** | 8 compiled executables tracked in git (`CheckboxGUItest.exe`, `FindDomain.exe`, `GUITest.exe`, `GetDomain.exe`, `NMGIupdates.exe`, `NMGIupdates.exe.fake3`, `TestChrome.exe`, `firefoxdump.exe`). **Remove from git tracking and add to `.gitignore`.** |

---

## 3. Recommended Lean Architecture & Data Model

### Technology Stack
- **Language**: AutoHotkey v2.0+ (strict 64-bit compatibility).
- **Automation Frameworks**: 
  - Microsoft UI Automation via `Lib/UIA.ahk` and `Lib/UIA_Browser.ahk` (Descolada) — primary engine.
  - Windows Media OCR via `Lib/OCR.ahk` (Descolada) — targeted secondary engine for canvas/non-UIA progress controls (QuickBooks).
- **Process & System Controls**: Native Windows Win32 API / AHK v2 built-ins (`Run`, `ProcessWaitClose`, `WinActivate`, `DllCall`).
- **Configuration & Cache**: Local INI storage (`GUIsettings.ini`).
- **No Heavy Runtimes**: Zero reliance on Python, Node.js, Electron, or external non-native frameworks. Kept as a fast, single-binary portable tool.

### Proposed Directory Layout
```text
NMGI-Updates/
├── .agents/                    # Agent governance and architectural rules
│   └── rules/
│       └── architecture.md
├── .gitignore                  # Ignore *.exe, *.log, *.bak, *.ini (local overrides)
├── CHANGELOG.md                # Human-readable release history
├── PROJECT_SPEC.md             # This document
├── CURRENT_TASK.md             # Active step-by-step milestone tracker
├── HANDOFF.md                  # Session transition log
├── GUIsettings.ini             # Application path cache ([Paths] section)
├── src/                        # Clean source organization
│   ├── NMGIUpdates.ahk         # Canonical entry point (renamed from CheckboxGUItest.ahk)
│   ├── Core/                   # Shared runtime services
│   │   ├── AppRegistry.ahk     # Declarative list of supported applications & categories
│   │   ├── Config.ahk          # INI cache read/write abstractions
│   │   ├── Logger.ahk          # Standardized yyMMdd-Update.log engine
│   │   └── ProcessHelper.ahk   # Universal process cleanup and wait logic
│   ├── Auth/                   # Authentication & modal handlers
│   │   ├── TRLogin.ahk         # Upfront Thomson Reuters CS credentials & MFA
│   │   ├── LacerteLogin.ahk    # Intuit Lacerte upfront credentials
│   │   ├── DatabaseLogin.ahk   # Upfront database passwords (Accounting CS, Practice CS, FPS)
│   │   └── Bulletins.ahk       # Universal dismissal of modal popups/bulletins
│   └── Modules/                # Isolated application update plugins
│       ├── UpdateUT.ahk
│       ├── UpdateFixedAssets.ahk
│       ├── UpdateFileCabinet.ahk
│       ├── UpdateAccountingCS.ahk
│       ├── UpdatePractice.ahk
│       ├── UpdateAdobe.ahk
│       ├── UpdateQB.ahk
│       ├── UpdateLacerte.ahk
│       ├── UpdateChrome.ahk
│       ├── UpdateEdge.ahk
│       └── UpdateFirefox.ahk
└── Lib/                        # Strictly vendor libraries
    ├── UIA.ahk
    ├── UIA_Browser.ahk
    └── OCR.ahk
```

### Data Model & Schemas

#### 1. Application Definition Object (Declarative App Registry)
Each supported application is defined as a clean record:
```ahk
{
    Id:       "Ultratax25",
    Label:    "UltraTax 2025",
    Category: 1, ; 1: Thomson Reuters, 2: Intuit/Accounting, 3: General, 4: Browsers
    PathFn:   (*) => GetUTPath("25"),
    RunFn:    (*) => UT("25")
}
```

#### 2. Configuration Schema (`GUIsettings.ini`)
Purge legacy domain mappings and standardize on explicit, clean sections:
```ini
[Paths]
Quickbooks Enterprise 22=C:\Program Files\Intuit\QuickBooks Enterprise Solutions 22.0\QBWEnterprise.exe
Quickbooks Enterprise 23=NotInstalled
Ultratax 25=\\wbsql1\WINCSI$\UT25\utw25.exe
Chrome=C:\Program Files\Google\Chrome\Application\chrome.exe
```

#### 3. Log Output Format (`yyMMdd-Update.log`)
Standardized line entries for auditability and GUI state parsing:
```text
UltraTax 2025 - Updates installed
Quickbooks Enterprise 24 - No updates
FileCabinet - Update still pending, users in application
Lacerte 2024 - Error (Main window timeout)
```

---

## 4. Architectural Boundaries (What We Are Intentionally NOT Building)

1. **Not a Generic Package Manager**:
   - Jacro is NOT a replacement for Winget, Chocolatey, or Ninite. It does not download generic installers from public repositories.
   - It is an orchestrator specifically designed for bespoke enterprise tax/accounting applications that lack headless command-line updaters and require active UI session navigation.
2. **No Multi-Language / Heavy Runtime Bloat**:
   - We are NOT embedding Python, Node.js, C#, or web-rendering runtimes (Electron/Tauri). 
   - Jacro must remain deployable as a standalone, ultra-lean executable running natively on Windows Server and client OS versions without pre-installing runtime dependencies.
3. **No Persistent Sensitive Credential Storage**:
   - We will NEVER store client passwords, firm credentials, or MFA secrets in `GUIsettings.ini`, the registry, or plain text on disk. 
   - All credentials must be collected in-memory via upfront GUI dialogs during the active operator session.
4. **No Legacy AHK v1 Support**:
   - The entire codebase is strictly AutoHotkey v2.0+. No compatibility layers for AHK v1 will be maintained.
5. **No Screen-Scraping / OCR as Primary Automation**:
   - Screen-scraping and OCR (optical character recognition) are fragile across varying screen resolutions, DPI scaling, and font rendering.
   - All modern automation MUST prioritize Microsoft UIAutomation (UIA) element queries, window messaging, and structured keyboard sequences over pixel-matching.
   - `Lib/OCR.ahk` is maintained solely as a targeted secondary engine for edge cases (specifically QuickBooks Desktop's custom-painted progress bar) where accessible UIA tree elements are entirely absent.
