\---

trigger: always\_on

description: "Core architectural boundaries and vibe coding governance"

\---



\# Project Governance \& Vibe Coding Rules



1\. \*\*State Engine Alignment\*\*: Always inspect `CURRENT\_TASK.md` and `HANDOFF.md` before starting any implementation.

2\. \*\*Atomic Commits\*\*: For every feature or bug fix, complete only the current step. Never write code for multiple unapproved steps at once.

3\. \*\*No Phantom Dependencies\*\*: Never introduce heavy third-party packages or complex state managers unless explicitly documented in `PROJECT\_SPEC.md`.

4\. \*\*Session Boundary Protocol\*\*: When prompted that a session is wrapping up, immediately update `HANDOFF.md` with:

&#x20;  - What was modified and tested.

&#x20;  - Any runtime bugs or unfinished logic.

&#x20;  - The exact next step in `CURRENT\_TASK.md`.

