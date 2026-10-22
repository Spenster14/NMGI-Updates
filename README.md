# Jacro (NMGI-Updates)

Automated client-maintenance and software-update orchestration system developed for **NMGI** to support CPA and accounting firm IT environments.

Jacro automates the discovery, credential collection, modal dialog navigation, update checking, patching, and post-update verification of complex desktop tax, accounting, and productivity suites across client workstations, terminal servers, and application hosts.

---

## Table of Contents
- [Architecture & Tech Stack](#architecture--tech-stack)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Operator Interface & Features](#operator-interface--features)
- [Authentication & Credential Workflow](#authentication--credential-workflow)
- [Application Support & Module Behaviors](#application-support--module-behaviors)
- [Logging & Post-Run Reporting](#logging--post-run-reporting)
- [Configuration & Caching (`GUIsettings.ini`)](#configuration--caching-guisettingsini)
- [Compilation & Testing](#compilation--testing)
- [Troubleshooting & Technician Notes](#troubleshooting--technician-notes)

---

## Architecture & Tech Stack

- **Runtime**: AutoHotkey v2.0+ (strictly 64-bit).
- **Automation Engines**:
  - **Microsoft UIAutomation (UIA v2)** via `Lib/UIA.ahk` and `Lib/UIA_Browser.ahk` (Descolada) — primary tree traversal and control invocation.
  - **Windows Media OCR** via `Lib/OCR.ahk` (Descolada) — secondary engine used specifically for canvas/non-UIA elements (e.g., QuickBooks update progress bars).
  - **Win32 Messaging & Control Automation**: Direct window messaging (`SendMessage`, `PostMessage`, `ControlClick`, `ControlSetText`) for legacy Win32, InstallShield (`SysTreeView32`), and Windows Forms controls.
- **Network UNC Reachability Guards**: Non-blocking Winsock (`ws2_32`) TCP port 445 connection checks with per-session caching (`SafeFileExist`). Eliminates the 25–30 second Windows SMB redirector hang when checking offline network shares or disconnected VPNs.
- **Zero Heavy Runtimes**: Standalone, portable executable. No Python, Node.js, Electron, or external runtime installations required.

---

## Prerequisites

1. **Operating System**: Windows 10, Windows 11, Windows Server 2016, 2019, 2022, or 2025 (64-bit).
2. **Privileges**: Administrator rights.
   - Jacro contains a self-elevation protocol. If launched non-elevated, it will automatically invoke UAC via `*RunAs` to restart itself with administrative privileges.
3. **Network Connectivity**:
   - If updating network-hosted suites (UltraTax, Practice CS, Accounting CS, FileCabinet, Fixed Assets), ensure the workstation is on-premises or connected to the client VPN with access to file/database servers (e.g., `\\sql1`, `\\wbsql1`, `\\tho1`, or mapped drives `W:`, `T:`, `X:`, `P:`).

---

## Quick Start

### Running the Precompiled Binary
Run `NMGIupdates.exe` as Administrator (or let it elevate via UAC).

### Running from Source
Ensure AutoHotkey v2 64-bit is installed:
```powershell
& "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" "NMGIUpdates.ahk"
```

### Initial Launch Experience
1. **Scanning Indicator**: On first launch, a tooltip (`Scanning applications, please wait...`) appears at screen coordinates `(100, 100)`.
2. **Environment Scan**: Jacro probes standard local program directories, mapped drives, and common client UNC paths. Initial discovery can take 20–25 seconds if multiple network paths must be evaluated.
3. **Path Caching**: Resolved paths are saved to `GUIsettings.ini` under `[Paths]`. Subsequent launches load near-instantaneously from this local cache.
4. **Dashboard Docking**: Once the scan finishes, the tooltip clears and the main dashboard docks automatically to the bottom-right corner of the primary display (`+AlwaysOnTop`).

---

## Operator Interface & Features

```
+-------------------------------------------------------------+
| Jacro V261022                                       [_][X]  |
+-------------------------------------------------------------+
| Select the applications to start:                           |
|                                                             |
| [X] Accounting CS     [X] UltraTax 2025      [X] Chrome     |
| [X] Practice CS       [X] FileCabinet        [X] Edge       |
| [X] UltraTax 2024     [X] PPC Tools          [X] Firefox    |
| [X] UltraTax 2023     [X] FPS                [X] Acrobat    |
|                                                             |
| Status:                                                     |
| [ Idle...                                                 ] |
|                                                             |
| [  Start  ]      [  Rescan  ]      [  Cancel  ]             |
+-------------------------------------------------------------+
```

### Priority Execution Ordering
Applications are sorted into functional categories and processed in an order designed to minimize operator friction:
- **Category 1 (Interactive TR Suites)**: `Accounting CS`, `Practice CS`. (Run first to trigger Thomson Reuters staff sign-in early).
- **Category 2 (Automated TR & Financial Apps)**: `UltraTax CS (25/24/23)`, `FileCabinet CS`, `Fixed Assets CS`, `PPC Tools`, `FPS`.
- **Category 3 (Intuit Accounting)**: `QuickBooks Desktop (Enterprise / Premier / Pro)`.
- **Category 4 (Tax & Document Systems)**: `Lacerte Tax (24/23/22)`, `Adobe Acrobat`.
- **Category 5 (Web Browsers)**: `Google Chrome`, `Microsoft Edge`, `Mozilla Firefox`.

### Visual Status Indicators
- **Standard (Black text)**: Application detected and ready for processing.
- **Bold Green text**: Updates were successfully downloaded/installed during today's session.
- **Light Gray text**: Application was checked and already has no pending updates today (`NotUpdated`).
- **Red text**: Error encountered, active lock conflict, or manual attention required.
- **Pulsing Orange text**: The application currently being updated.

### Technician Shortcuts & Controls
| Control / Action | Behavior |
| :--- | :--- |
| **Start** | Prompts for upfront credentials (if required) and executes updates for all checked applications. |
| **Rescan** | Clears the host reachability cache, forces a complete network/local rescan, and refreshes `GUIsettings.ini`. |
| **Shift + Right-Click "Rescan"** | **Quick-filter**: Automatically unchecks all applications that have already been processed today (Bold Green or Light Gray). Ideal for resuming or retrying failed items. |
| **Click Text Label** | Clicking any application text toggles its corresponding checkbox. |
| **Cancel** | Gracefully closes the dashboard. |

---

## Authentication & Credential Workflow

### Centralized Upfront Prompting
Jacro eliminates mid-run modal blocking by collecting all required credentials in a single dialog before the update loop begins.

When clicking **Start**, if any selected applications require authentication, Jacro displays a unified modal:
- **Accounting CS Database Password**: For the SQL database firm login.
- **Practice CS Database Password**: For the SQL database firm login.
- **FPS (Financial Planning Suite) Password**: For the "Log User Into System" dialog.
- **Lacerte Credentials**: Email and password for Intuit online authentication.

### Thomson Reuters Staff Sign-In
Thomson Reuters CS applications that require staff credentials launch an initial sign-in modal. `Auth/TRLogin.ahk` orchestrates the staff authentication flow upfront.

### Security Guarantee
- **Strict In-Memory Policy**: All entered passwords and credentials exist strictly in volatile AHK process memory during the active execution run.
- **Zero Persistence**: Credentials are **never** written to `GUIsettings.ini`, the registry, or plain text log files on disk.

---

## Application Support & Module Behaviors

### 1. Thomson Reuters CS Suite
- **Practice CS & Accounting CS**:
  - Automatically targets the borderless Windows Forms login dialog and injects the database password.
  - Excludes ComboBox child edit controls (`Open Firm`, `Staff ID`) and anchors strictly to the `"Password:"` row.
  - Implements a patient single-submit routine that waits up to 45 seconds for SQL database verification without re-submitting.
  - Automatically detects credential rejection errors (`"not valid for the Firm"`), dismisses all cascading popups, closes the login card, and flags `" - Error (Invalid credentials)"`.
  - Navigates CS Connect ("Call Now") and inspects the Call Summary.
  - **Manual/Deferred Mode**: To prevent accidental firm-wide database locks while other staff are working, updates are set to manual / deferred installation.
- **UltraTax CS (2023, 2024, 2025)**:
  - Discovers multi-year local or network instances (`\\wbsql1\WINCSI$\UTxx\utwxx.exe`).
  - Connects via CS Connect, monitors download status, handles user bulletins/popups, and dismisses post-update restart prompts.
- **FileCabinet CS & Fixed Assets CS**:
  - Handles `fcab.exe` and `dsw.exe`.
  - Detects active-user locks (`"Users currently in application"`) and logs the condition without crashing.

### 2. Thomson Reuters PPC Tools & Practice Aids
- Module: `Lib/UpdatePPC.ahk` (`PPCWebMultiSelect.exe`).
- Navigates through the installer introduction.
- Directly queries the Win32 `SysTreeView32` common control (`TVM_GETITEMSTATE` with `TVIS_STATEIMAGEMASK`) to inspect pending product checkboxes in under 1ms.
- If updates are checked: flags `" - Updates available (Manual)"`. If none: flags `" - No updates"`.
- Cleanly cancels the installer and handles the confirmation modal (`"Are you sure you want to cancel the installation? -> Yes"`).

### 3. Financial Planning Suite (FPS / FAS)
- Module: `Lib/UpdateFPS.ahk` (`FAS.EXE -r`).
- Automatically injects the database password into the "Log User Into System" modal.
- Automatically dismisses the "Open a Client" picker (`btnCancel`).
- Navigates via Help menu to "Check for Updates" and verifies version matching (`lblWebVersion` vs `lblVersion`).
- Dismisses the post-update "Web Registration" dialog (`"Do you want to run FAS Accounting? -> No"`).

### 4. Intuit QuickBooks Desktop
- Module: `Lib/UpdateQB.ahk`.
- Supports Enterprise, Premier, and Pro (versions 21–24).
- Suppresses the welcome screen by temporarily configuring `QBWUSER.INI`.
- Automatically detects and dismisses license expiration warnings ("Quickbooks subscription expired" / "subscription expiring") by clicking "Close", allowing the application to launch and update normally.
- Uses Windows Media OCR (`Lib/OCR.ahk`) to read the custom-rendered progress bar and status text during updates.
- Inspects `Install.log` to confirm final patch application.

### 5. Intuit Lacerte Tax
- Module: `Lib/UpdateLacerte.ahk`.
- Supports tax years 22, 23, and 24.
- Injects upfront Lacerte credentials via WPF and Delphi control navigation.
- Automates the Update Center and confirms version readiness.

### 6. Adobe Acrobat
- Module: `Lib/UpdateAdobe.ahk`.
- Supports Acrobat DC (Continuous) and Acrobat 2020 (Classic).
- Automatically identifies the UI layout:
  - **Modern New Experience UI**: Navigates Hamburger Menu (`Alt+F` $\rightarrow$ `L` $\rightarrow$ `C`).
  - **Classic DC UI**: Menu Bar (`Alt+H` $\rightarrow$ `C`).
  - **Acrobat 2020 UI**: Menu Bar (`Alt+H` $\rightarrow$ `U`).
- Bypasses unlicensed trial splash dialogs in <350ms.
- Monitors `AdobeARM.exe` and handles download/install sequences.

### 7. Web Browsers (Chrome, Edge, Firefox)
- Modules: `Lib/UpdateChrome.ahk`, `Lib/UpdateEdge.ahk`, `Lib/UpdateFirefox.ahk`.
- Uses `Core/Process.ahk` to terminate existing zombie or orphan browser processes before updating.
- Launches directly to internal help endpoints:
  - `chrome://settings/help`
  - `edge://settings/help`
  - About Mozilla Firefox modal
- Monitors download and install status via UIA, clicks "Relaunch" / "Restart" buttons, and waits for confirmation of up-to-date status.

---

## Logging & Post-Run Reporting

### 1. Daily Audit Log (`yyMMdd-Update.log`)
Located in the script/executable root folder. Records standardized execution timestamps and status lines:
```text
[09:15:22] UltraTax 2025 - Updates installed
[09:16:04] FileCabinet - No updates
[09:17:30] PracticeCS - Updates available (Manual)
[09:18:15] AccountingCS - Error (Invalid credentials)
[09:20:02] Chrome - Updates installed
```

### 2. Post-Run Summary Modal
When a batch run finishes, Jacro displays a consolidated summary report (`ShowSummaryReport`):
- **Updated**: Count and list of applications updated this run.
- **Already Current**: Count of applications that needed no updates.
- **Attention Required**: Applications with updates found that require manual intervention or server coordination.
- **Errors**: Failures, timeouts, or invalid credentials.

---

## Configuration & Caching (`GUIsettings.ini`)

`GUIsettings.ini` is created automatically in the application directory. It is machine-specific and excluded from version control.

```ini
[Paths]
UltraTax 2025=\\wbsql1\WINCSI$\UT25\utw25.exe
UltraTax 2024=\\wbsql1\WINCSI$\UT24\utw24.exe
PracticeCS=\\sql1\winCSI\Practice CS\CreativeSolutions.Practice.exe
AccountingCS=C:\WinCSI\Accounting CS\CreativeSolutions.Accounting.exe
Adobe Acrobat=C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe
Chrome=C:\Program Files\Google\Chrome\Application\chrome.exe
Quickbooks Enterprise 24=NotInstalled

[Status]
UltraTax 2025=Updated
PracticeCS=NotUpdated
Chrome=Updated
```

- **Resetting Paths**: If paths change or an application was moved, click **Rescan** in the GUI, or delete `GUIsettings.ini` to regenerate it from scratch.
- **Marking as Not Installed**: If an application is not present on the host, it is recorded as `NotInstalled` to skip probing on future launches.

---

## Compilation & Testing

### Recompiling `NMGIupdates.exe`
Use the AutoHotkey v2 compiler (`Ahk2Exe.exe`):
```powershell
& "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" `
    /in "NMGIUpdates.ahk" `
    /out "NMGIupdates.exe" `
    /base "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
```

### Automated Smoke Testing
Test the script syntax and verify non-crashing initialization without performing active UI updates using the `/smoke` flag:

**Source test**:
```powershell
& "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" "NMGIUpdates.ahk" /smoke
```

**Compiled binary test**:
```powershell
.\NMGIupdates.exe /smoke
```

*(Note: `/smoke` runs in non-elevated mode and exits after initializing dependencies).*

---

## Troubleshooting & Technician Notes

1. **Slow Startup / Hang on "Scanning applications"**:
   - The initial scan probes network UNC hosts.
   - If an SMB host is completely offline, `SafeFileExist` tests port 445 with a fast 1-second timeout and caches offline status. Subsequent checks to that host bypass instantly.
   - If you connected to VPN *after* launching Jacro, click **Rescan** to flush the host cache and detect shares.
2. **Practice CS / Accounting CS Password Errors**:
   - If a technician enters the wrong password, Jacro will wait for database validation, detect the error dialog, dismiss all warning popups, cancel the login card, and log `" - Error (Invalid credentials)"`.
   - Re-check the password, click **Start**, and re-enter the correct credentials.
3. **Practice CS "Open Firm" Field Overwritten**:
   - This issue was permanently resolved in Step 4.4g by filtering out ComboBox child edits (`DllCall("GetParent")`) and anchoring strictly to the `"Password:"` label.
   - If an open firm field was previously corrupted by manual typing, Jacro auto-recovers by sending `CB_SETCURSEL 0` to restore the first valid firm in the list.
4. **PPC Tools Confirmation Dialog**:
   - If PPC Tools is cancelled, an InstallShield confirmation prompt asks `"Are you sure you want to cancel the installation?"`. Jacro handles this automatically by targeting the top-most modal window and selecting "Yes".
5. **QuickBooks OCR Warnings**:
   - QuickBooks Desktop uses custom GDI rendering for update progress bars. Ensure display scaling is set to 100% or standard DPI on the host server if OCR reads fail.
