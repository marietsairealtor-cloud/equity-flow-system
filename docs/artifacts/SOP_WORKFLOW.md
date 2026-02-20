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
"Nothing to commit" ≠ complete

One objective = One PR

No multi-objective PRs.

---

## 2) Proof-Only Work Rule

If an objective requires no functional code change:

A Proof PR is still required containing at least one:

- Committed proof artifact under docs/proofs/**
- pgTAP / invariant assertion
- DEVLOG update with evidence

Proof must be:

- In-repo
- Commit-bound (PROOF_HEAD + scripts hash authority)
- CI validated (proof-manifest + proof-commit-binding)

Screenshots, pasted terminal output, or out-of-branch evidence are invalid.

---

## 3) Proof Artifact Sequencing (LOCKED)

**Objective:** Produce exactly **one final proof log per Build Route item**, bound to a tested commit, with a machine-managed manifest.

---

### 3.1 Core Rules

**Rule A — Proof is last**
Do not touch proofs until implementation is complete and all required local checks are green.

**Rule B — Proof log is NOT automatic**
`npm run proof:finalize` does **not** generate the proof log.
The coder must first create the proof log file under `docs/proofs/**` by running the relevant gate and saving its output.

**Rule C — Manifest is machine-managed**
`docs/proofs/manifest.json` must never be edited manually.
The only permitted mutation path is:
```
npm run proof:finalize docs/proofs/<ITEM>_<UTC>.log
```

**Rule D — No non-proof changes after PROOF_HEAD (HARD STOP)**
After `proof:finalize` runs (PROOF_HEAD established), all subsequent commits in the PR may modify only:

* `docs/proofs/**`

Any non-proof change after finalize is forbidden and requires restarting proof generation.

**Rule E — One canonical proof log per item per PR**
Iteration is allowed locally, but the PR must end with exactly **one canonical proof log** for the item.

---


### 3.2 Minimal Procedure (Required Order)

1. Complete all implementation changes. All code, truth files, and
   workflow changes must be committed before proof begins.

2. Allowlist the canonical proof log path in
   scripts/ci_robot_owned_guard.ps1 before creating the log.

   - All new proof logs are subject to robot-owned-guard.
     No exceptions.
   - The exact canonical filename (docs/proofs/<ITEM>_<UTC>.log)
     must be present in scripts/ci_robot_owned_guard.ps1 before
     Step 5.
   - This is an implementation change. Commit it in Step 1,
     not as part of the proof tail.

3. Run:
   npm run pr:preflight

4. Run the relevant gate. Save output to:
   docs/proofs/<ITEM>_WORKING.log
   Iterate until gate output shows PASS. No non-proof changes
   between iterations.

5. Rename to canonical form:
   docs/proofs/<ITEM>_<UTC>.log
   Filename must exactly match the path allowlisted in Step 2.
   Mismatch = robot-owned-guard will fail.

6. Finalize exactly once:
   npm run proof:finalize docs/proofs/<ITEM>_<UTC>.log

7. Commit only:
   - docs/proofs/<ITEM>_<UTC>.log
   - docs/proofs/manifest.json

8. Open PR → CI green → QA approve → merge.

---

### 3.3 Repair Protocol (If You Created Multiple Proof Logs)

If a proof/manifest mistake causes CI to go red (duplicate proof logs, stale manifest entry, or broken proof tail):

**Canonical repair (mechanical):**
1. Identify the last clean commit **before any proof/finalize/manifest changes** (`PREPROOF_HEAD`).
2. Reset the branch to `PREPROOF_HEAD` (discard the broken proof tail).
3. Fix the underlying objective/gate issue (non-proof work) until CI/local gates are green.
4. Generate the proof log again (canonical `<UTC>.log` only).
5. Run `npm run proof:finalize -- -File docs/proofs/<proof_log>.log` exactly once.
6. After finalize: proof-only tail commits only (`docs/proofs/**` + optional `docs/DEVLOG.md`).
7. Push.

**Do NOT** attempt to "prune" manifest entries via delete-first + re-finalize; `proof:finalize` does not prune and `ci_proof_manifest` will fail on stale entries.

---

## 4) QA Submission Rule (LOCKED)

QA review occurs after CI is green.

Before QA review, the operator must provide:

- PR number and branch name
- PR diff (or changed file list)
- Proof artifact path (if applicable)
- Manifest status (if applicable)
- CI checks evidence showing:
  - CI / required = SUCCESS (not skipped)
  - Any newly introduced gate = SUCCESS
- Gate output evidence:
  - If implementing a new gate: output from the new gate showing PASS
  - If in Debugger Mode: output from the first failing gate (before and after fix)
  - Otherwise: CI checks screenshot showing `required` job green is sufficient

QA must reject the submission if required-check status evidence is missing or ambiguous.

QA must return:

- APPROVE
- or
- REJECT (first failing gate only)

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

### Allowed in Git Bash:
- `git status`, `git log`, `git diff`, `git branch`
- `git checkout`, `git pull`, `git push`, `git fetch`
- Simple file inspection (`cat`, `head`, `tail`, `less`)
- `ls`, `pwd`, `cd`

### NOT Allowed in Git Bash (use pwsh):
- `git add --renormalize` (encoding-sensitive)
- Running `.ps1` scripts
- Proof generation or `proof:finalize`
- Any file-writing operation
- npm scripts that invoke PowerShell

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

## 13) Gate Close — Post-Merge Verification (LOCKED)

After merge to main:

```
git checkout main
git pull
git status           → must show clean working tree
npm run pr:preflight → must pass
npm run ship         → must PASS, zero diffs, exit 0
```

If `ship` fails on main after merge, enter Debugger Mode immediately.

`docs/handoff_latest.txt` internal git status line is informational only and not authoritative.

---

## 14) DEVLOG Entry Rules (LOCKED)

### When to Add Entry

A DEVLOG entry is REQUIRED for:

- Build Route item completion (PR merged)
- Build Route additions or modifications
- Advisor review findings
- Governance artifact updates (AUTOMATION, CONTRACTS, GUARDRAILS, SOP_WORKFLOW)
- Truth file changes (`docs/truth/*.json`)
- Incident acknowledgment (INCIDENTS.md entry)
- Waiver usage (WAIVER_PR*.md created)
- Remediation actions following audit findings
- Status corrections to prior entries
- Proof repair (PREPROOF_HEAD reset)
- CI gate additions or removals
- Toolchain version changes
- Foundation boundary or invariant changes

### When NOT to Add Entry

Do not add entries for:

- Routine CI runs
- Failed or abandoned PRs
- Local debugging sessions
- Draft/WIP work
- Branch creation without merge

### Timing

DEVLOG entry is added **after the item is QA-approved and merged to main**.
The entry is committed in the next PR or a standalone governance PR.
DEVLOG is never part of the proof tail commit.

### Format (LOCKED)

```
YYYY-MM-DD — Build Route vX.Y — Item

Objective
Changes
Proof
DoD
Status
```

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

### When to run handoff

Run `handoff` + `handoff:commit` on the **PR branch, before merge**, when the PR changes anything that affects truth artifacts:

* Migration changes (supabase/migrations/**)
* Schema changes
* Contract changes (CONTRACTS.md or snapshot)
* Any change that would alter generated/schema.sql, generated/contracts.snapshot.json, or docs/handoff_latest.txt

Do NOT run handoff for governance-only PRs (CI wiring, docs, proof-only work) that do not touch the DB or contracts.

### When to run ship

Run `ship` on **main, after merge**, as the post-merge verification step (see §13).

ship never generates. ship never commits. ship never pushes.

### Summary

| Command | When | Branch | Writes files? |
|---------|------|--------|---------------|
| handoff | Before merge | PR branch | Yes (truth artifacts) |
| handoff:commit | Before merge | PR branch | Yes (commits + pushes artifacts) |
| ship | After merge | main only | No (verify-only) |

---

## 17) Governance-scoped paths (ENFORCED)

Governance scope is defined by `docs/truth/governance_change_guard.json`.
Any PR that changes a governance-scoped path **must** include:

`docs/governance/GOVERNANCE_CHANGE_PR<NNN>.md`

Required template sections:
- What changed
- Why safe
- Risk
- Rollback

### Always Governance (GOVERNANCE_CHANGE_PR<NNN>.md required)

- `docs/truth/**`
- `.github/workflows/**`
- `scripts/**`
- `docs/artifacts/GUARDRAILS.md`
- `docs/artifacts/CONTRACTS.md`
- `docs/artifacts/AUTOMATION.md`
- `docs/artifacts/SOP_WORKFLOW.md`
- `docs/artifacts/FOUNDATION_BOUNDARY.md`
- `supabase/foundation/**`

### Explicitly Exempt (does not trigger governance)

- `docs/DEVLOG.md`

### Merge-blocking requirement (LOCKED)

Governance enforcement is valid only if CI is merge-blocking:

- Jobs `governance-change-guard` and `governance-change-template-contract` must run on `pull_request`.
- The aggregate merge-blocking job (`required`) must include both jobs in its `needs:` list **string-exactly** (or GitHub rulesets must require them string-exactly).

If a governance-scoped file is modified and CI does not block merges without the governance change template, the repository is noncompliant until the required-check wiring is corrected.

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
