# SOP_WORKFLOW.md

Authoritative — Governed Execution (Final Aligned Version)

---

## 0) Authoritative Load Order (LOCKED)

Load and obey in this exact order:

1. Build Route
2. docs/handoff_latest.txt
3. docs/CONTRACTS.md
4. docs/GUARDRAILS.md
5. docs/AUTOMATION.md
6. docs/SOP_WORKFLOW.md
7. docs/DEVLOG.md

Conflict rule:
handoff → guardrails → build route wins

If any instruction conflicts with Command for Chat, Command for Chat wins.

---

## 1) Completion Law (AUTHORITATIVE)

An objective is complete ONLY if:

PR opened → CI green → approved → merged

No PR = not complete
Local pass ≠ complete
“Nothing to commit” ≠ complete

One objective = One PR

No multi-objective PRs.

---

## 2) Proof-Only Work Rule

If an objective requires no functional code change:

A Proof PR is still required containing at least one:

* Committed proof artifact under docs/proofs/**
* pgTAP / invariant assertion
* DEVLOG update with evidence

Proof must be:

* In-repo
* Commit-bound
* CI validated

Screenshots or pasted terminal output are invalid.

---

## 3) Proof Artifact Sequencing (LOCKED)

Required order:

1. Implement objective
2. Run required local gates
3. Generate proof artifact under `docs/proofs/**`
4. Update manifest (if required)
5. Commit proof artifact
6. Open PR
7. CI must reach green
8. Submit PR evidence to QA
9. Receive explicit QA APPROVE
10. Merge

Completion requires: **PR opened → CI green → approved → merged**.

---

## 4) QA Submission Rule (LOCKED)

QA review occurs **after CI is green**.

Before QA review, the operator must provide:

- PR number and branch name
- PR diff (or changed file list)
- Proof artifact path (if applicable)
- Manifest status (if applicable)
- CI checks evidence showing:
  - CI / required = SUCCESS (not skipped)
  - Any newly introduced gate = SUCCESS
- Gate output (local or CI where relevant)

QA must reject the submission if required-check status evidence is missing or ambiguous.


QA must return:

* APPROVE
* or
* REJECT (first failing gate only)

No merge is valid without QA approval.

---

## 5) Operating Modes

### 5.1 Executor Mode (Default)

Use when:

* Implementing a scoped Build Route item
* Producing required artifacts

Rules:

* One objective → one PR
* No redesign
* No debugging unless triggered

---

### 5.2 Debugger Mode (Triggered Only)

Enter Debugger Mode if ANY:

* A gate is red (local or CI)
* Same named gate fails twice
* A blocking error prevents required proof generation

Debugger Mode Rules:

* Identify first failing gate by name
* Fix that gate only
* Exit once green
* Do not redesign system
* Do not stack fixes

---

## 6) Execution Format (Session Rule)

Interactive step responses must follow the exact execution format defined in Command for Chat.

This governs session output only and does not alter documentation structure.

---

## 7) Shell Discipline (LOCKED)

Execution Shell Policy (Authoritative)

Default interactive shell on Windows is pwsh (PowerShell 7) for objectives involving:

* proof generation
* manifest updates
* file-writing scripts
* governance / CI scripts

Git Bash may be used for lightweight git or Unix-style operations only if chosen at objective start.

Execution surface is locked per objective (one PR):

* Do not switch shells mid-objective.
* If shell change is required due to instability, close or restart the objective and continue in the new shell.

Rationale:
Prevent encoding drift, line-ending corruption, and proof-binding failures.
Maintain deterministic auditability.

---

## 8) Proof-Commit-Binding Compliance

For all docs/proofs/** artifacts:

### 8.1 PROOF_HEAD

* Must equal tested SHA at runtime
* Must be ancestor of PR_HEAD
* Commits after PROOF_HEAD may modify only:

  * docs/proofs/**
  * optionally docs/DEVLOG.md

---

### 8.2 PROOF_SCRIPTS_HASH

Must be:

* Deterministic
* Explicit file list (no globbing)
* Deterministic ordering
* CRLF normalized to LF before hashing

Must match:

* AUTOMATION.md specification
* Validator implementation
* Proof log header

Mismatch = FAIL.

---

## 9) CI Lane Isolation (Policy)

Docs-only PR:

* Skip DB-heavy tests
* Run minimal gates only

Artifacts-only PR:

* Run drift + policy + proof-commit-binding
* Skip full DB suite

Code PR:

* Run full CI

If YAML does not enforce this, repository is noncompliant until corrected via objective PR.

---

## 10) Waiver Debt Enforcement (Build Route 2.16.4)

Waivers must be:

* Explicit
* Scoped
* Time-bounded
* Auditable

Expired waivers must fail CI.

Waiver removal requires:
PR opened → CI green → approved → merged

---

## 11) Stop Conditions (LOCKED)

Stop immediately if:

* Authoritative file missing
* CI red
* Unexpected file drift
* Build Route ambiguity

When a stop condition is triggered:

* Do not proceed with implementation
* Do not switch modes to bypass
* Do not redesign system
* Resolve the blocking issue first

---

## 12) Forbidden Actions

The following are prohibited:

* Hand-edit robot-owned files
* Commit directly to main
* Merge on red CI
* Open PR without required proof artifacts
* Merge without QA approval
* Multi-objective PRs
* Retro-edit historical migrations
* Introduce dynamic SQL in migrations
* Bypass proof artifact requirements

Violation = governance failure.

---

## 13) Gate Close — Clean Tree Verification

After merge to main:

git checkout main
git pull
git status → must show clean working tree
npm run ship → must pass

`docs/handoff_latest.txt` internal git status line is informational only and not authoritative.

---

## 14) DEVLOG Entry Format (LOCKED)

Entries must follow exactly:

YYYY-MM-DD — Build Route vX.Y — Item

Objective
Changes
Proof
DoD
Status

No structural deviation allowed.

---

## 15) Local Green Gate Loop (LOCKED)

Required sequence:

* green:once
* green:twice

Both runs must pass with no edits between runs.

No generators may run during the gate loop.

---

## 16) Truth Artifact Rule (LOCKED)

Truth files are generated only via:

* npm run handoff
* npm run handoff:commit

ship is verify-only.

---

STATUS:
Aligned with Command for Chat
Aligned with Build Route v2.4
Aligned with AUTOMATION
Aligned with GUARDRAILS
Proof-before-PR enforced
CI-green-before-QA enforced
QA-before-merge enforced
Stop conditions hardened
Execution surface stability enforced
Governance stack consistent
