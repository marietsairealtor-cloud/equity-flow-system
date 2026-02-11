# SOP_WORKFLOW.md
Authoritative — Governed Execution (Fully Aligned with Command for Chat)

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

---

## 2) Proof-Only Work Rule

If an objective requires no functional code change:

A Proof PR is still required containing at least one:

- Committed proof artifact under docs/proofs/**
- pgTAP / invariant assertion
- DEVLOG update with evidence

Proof must be:

- In-repo
- Commit-bound
- CI validated

Screenshots or pasted terminal output are invalid.

---

## 3) Proof Artifact Sequencing (LOCKED)

Required order:

1. Implement objective
2. Run required local gates
3. Generate proof artifact under docs/proofs/**
4. Update manifest (if required)
5. Commit proof artifact
6. Submit proof evidence to QA
7. Receive explicit QA PASS
8. Open PR

A PR opened without required proof artifacts and QA PASS is invalid.

---

## 4) QA Submission Rule (LOCKED)

Before opening a PR, the operator must provide:

- PR diff (or staged file list)
- Proof artifact path
- Gate output
- Manifest status (if applicable)

QA must return:

PASS  
or  
FAIL (with first failing gate)

No PR is valid without QA PASS.

---

## 5) Operating Modes

### 5.1 Executor Mode (Default)

Use when:
- Implementing a scoped Build Route item
- Producing required artifacts

Rules:
- One objective → one PR
- No redesign
- No debugging unless triggered

### 5.2 Debugger Mode (Triggered Only)

Enter Debugger Mode if ANY:

- A gate is red (local or CI)
- Same named gate fails twice
- A blocking error prevents required proof generation

Debugger Mode Rules:

- Identify first failing gate by name
- Fix that gate only
- Exit once green
- Do not redesign system

---

## 6) Execution Format (Session Rule)

For interactive execution steps, follow Command for Chat execution format exactly.

This governs session responses only and does not alter documentation structure.

---

## 7) Shell Discipline (LOCKED)

Default interactive shell: Git Bash (MINGW64)

PowerShell allowed only when:
- Windows-safe file writing required
- Encoding control required
- Running PowerShell-based gates

Do not mix shells inside a single command block.

Execution Surface Stability Rule:

During a single objective/PR:
- Do not change shell
- Do not introduce a new runtime
If required → stop and open a new objective.

---

## 8) Proof-Commit-Binding Rules

For all docs/proofs/** artifacts:

### 8.1 PROOF_HEAD
- Must equal tested SHA at runtime
- Must be ancestor of PR_HEAD
- Commits after PROOF_HEAD may modify only:
  - docs/proofs/**
  - optionally docs/DEVLOG.md

### 8.2 PROOF_SCRIPTS_HASH
Must be:

- Deterministic
- Explicit file list (no globbing)
- Deterministic ordering
- CRLF normalized to LF before hashing

Hash must match between:

- AUTOMATION.md specification
- Validator implementation
- Proof log header

Mismatch = FAIL.

---

## 9) Truth Artifact Rule

Truth files are generated only via:

npm run handoff  
npm run handoff:commit  

ship is verify-only.

Hand-editing robot-owned files is forbidden.

---

## 10) Local Green Gate Loop

green:once  
green:twice  

Must pass twice with no edits between.

No generators allowed during gate loop.

---

## 11) CI Lane Isolation

Docs-only PR:
- Skip DB-heavy tests
- Run minimal gates only

Artifacts-only PR:
- Run drift + policy + proof-commit-binding
- Skip full DB suite

Code PR:
- Run full CI

If workflow YAML does not enforce this, system is noncompliant until corrected via objective PR.

---

## 12) Waiver Debt Enforcement (Build Route 2.16.4)

Waivers must be:

- Explicit
- Scoped
- Time-bounded
- Auditable

Expired waivers must fail CI.

Waiver removal requires:
- Proof artifact
- CI green
- PR opened → approved → merged

---

## 13) Gate Close — Clean Tree Verification

After merge to main:

git checkout main  
git pull  
git status → must show clean working tree  
npm run ship → must pass  

The git status line inside docs/handoff_latest.txt is informational only and not authoritative for tree cleanliness.

---

## 14) Stop Conditions (LOCKED)

Stop immediately if:

- Authoritative file missing
- CI red
- Unexpected file drift
- Build Route ambiguity

When a stop condition is triggered:

- Do not proceed with implementation
- Do not switch modes to bypass
- Do not redesign system
- Request clarification
- Resolve the blocking condition first

---

## 15) Forbidden Actions (LOCKED)

The following are prohibited:

- Hand-edit robot-owned files:
  - docs/handoff_latest.txt
  - generated/schema.sql
  - generated/contracts.snapshot.json
  - .gitattributes
- Dynamic SQL in migrations ($$, EXECUTE)
- Commit directly to main
- Retro-edit historical migrations
- Infer script lists for hashing
- Skip required proof artifacts
- Open PR without QA PASS
- Merge on red CI

Violation = governance failure.

---

## 16) DEVLOG Entry Format (LOCKED)

Entries must follow exactly:

YYYY-MM-DD — Build Route vX.Y — Item

Objective  
Changes  
Proof  
DoD  
Status  

No structural deviation allowed.
