# SOP_WORKFLOW.md

Authoritative — Governed Execution (Revised 2026-03-19)

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

## 0.1) Quick-Reference Execution Checklist

Use this as a session startup reminder. Full rules for each step are in §1.

**Phase 1 — Implementation**
- [ ] Branch from clean main
- [ ] Implement DoD (code, scripts, migrations, tests)
- [ ] Triple-register any new `docs/truth/**` file
- [ ] Author manual-only files (migrations, tests, CONTRACTS.md, governance file)
- [ ] Run all Phase 1 gate pre-checks (§1 Phase 1 Step 4) — see §18 for over-trigger behaviors
- [ ] Commit all implementation changes

**Phase 2 — Truth Artifacts *(skip if PR does not touch DB/contracts/schema/handoff pipeline)**
- [ ] `npm run handoff`
- [ ] `npm run handoff:commit`

**Phase 3 — Verification**
- [ ] `node scripts/ci_semantic_contract.mjs`
- [ ] `npm run green:once` — PASS
- [ ] `npm run green:twice` — PASS (no edits between runs)
- [ ] `npm run pr:preflight`

**Phase 4 — Proof**
- [ ] Run gate → save to `docs/proofs/<ITEM>_WORKING.log`
- [ ] Rename to `docs/proofs/<ITEM>_<UTC>.log`
- [ ] `npm run proof:finalize docs/proofs/<ITEM>_<UTC>.log`
- [ ] Commit only: proof log + manifest.json

**Phase 5 — Review and Merge**
- [ ] CI green → submit QA evidence
- [ ] QA APPROVE → merge

**Phase 6 — Post-Merge**
- [ ] `git checkout main && git pull`
- [ ] `npm run ship` — zero diffs
- [ ] `npm run handoff` — zero diffs

**Phase 7 — DEVLOG**
- [ ] DEVLOG entry in next PR (never in proof tail)

---

## 1) Full Execution Procedure (LOCKED)

This is the complete step-by-step sequence from starting an objective to closing it. Every Build Route item follows this procedure. No steps may be skipped.

### Phase 1 — Implementation (Engineering & Authorship)

**Step 1 — Branch Initialization**
- Checkout: Create a PR branch from a clean, up-to-date `main`.
- Identification: Confirm and record the target Build Route Item ID (e.g., `10.8.6A`).

**Step 2 — Implementation & Engineering (The DoD)**

Complete all technical and functional changes defined in the Build Route objective:
- Logic/Scripts: Author or modify any required scripts, backend logic, or application code.
- QA checks and passes all the required scripts, backend logic, or application code.
- Write-RPC success tests must seed an active subscription under the current contract.
- Run DB reset and pass test db on migration files before DB push. 
- Pipeline Wiring: Update `scripts/handoff.ps1` or relevant workflow files to integrate the new functionality.
- CI/Enforcement: Apply any required fixes to CI guard scripts (e.g., `ci_governance_change_guard.ps1`) to ensure the new state is valid.
- Triple-Registration: If introducing a NEW file under `docs/truth/**`, it must be registered in:
  1. Robot-owned guard (`scripts/ci_robot_owned_guard.ps1`)
  2. Truth-bootstrap (`scripts/truth_bootstrap_check.mjs`)
  3. Handoff regeneration (`scripts/handoff.ps1`)

**Step 3 — Manual-Only Files (Human Authorship)**

Author the files that require human architectural intent. These are never overwritten by robot scripts:
- Migrations: `supabase/migrations/*.sql` — the authoritative system state
- Tests: `supabase/tests/*.test.sql` — behavioral verification logic
- Contracts: `docs/artifacts/CONTRACTS.md` — architectural laws and RPC mappings
- Governance: `docs/governance/GOVERNANCE_CHANGE_<UTC>.md` — justification for the change
- Manual Registries: `calc_version_registry.json`, `rpc_contract_registry.json`, `privilege_truth.json`

**Step 4 — Pre-emptive Gate Alignment (Sanity Checks)**

Verify the implementation against automated CI gates before committing. See §18 for known gate over-trigger behaviors before assuming a CI failure is a real violation.

| Condition | Gate | Required Action |
|---|---|---|
| Migration contains calc-logic token | `ci_calc_version_lint` | Update `calc_version_registry.json` |
| Migration changes schema | `ci_entitlement_policy_coupling` | Add note to `CONTRACTS.md` |
| SQL comments contain non-ASCII | `ci_encoding_audit` | Fix to ASCII hyphens + alphanumeric only |
| New SECURITY DEFINER function | `definer-safety-audit` | Add to `definer_allowlist.json` |
| New public RPC | `rpc-mapping-contract` | Add row to `CONTRACTS.md` mapping table |
| New public RPC | `rpc-contract-registry` | Add entry to `rpc_contract_registry.json` |
| New public RPC | `anon-privilege-audit` | Add to `execute_allowlist.json` + `privilege_truth.json` |
| New tenant-scoped table | `unregistered-table-access` | Add to `tenant_table_selector.json` |
| Every item | `qa-scope-coverage` | Update `qa_claim.json` + `qa_scope_map.json` |
| Every item | `robot-owned-guard` | Allowlist proof log path in `ci_robot_owned_guard.ps1` |

**Step 5 — Commit Implementation**
- Stage and commit all authored and engineered files from Steps 2, 3, and 4.
- Final Rule: This commit represents the "Human Truth." Do not run `handoff` until this implementation state is committed to the branch.

---

### Phase 2 — Truth Artifacts *(skip if PR does not touch DB/contracts/schema/handoff pipeline)*

**Step 6 — Generate Truth Artifacts**

Run: `npm run handoff`

`handoff` regenerates:
- `generated/schema.sql`
- `generated/contracts.snapshot.json`
- `docs/handoff_latest.txt`
- `docs/truth/write_path_registry.json`

`handoff` also runs `sync_truth_registries.mjs` which auto-overwrites (when DB is available):
- `docs/truth/tenant_table_selector.json` — from Postgres RLS catalog
- `docs/truth/definer_allowlist.json` — from Postgres SECURITY DEFINER catalog
- `docs/truth/execute_allowlist.json` — from Postgres EXECUTE grants catalog
- `docs/truth/cloud_migration_parity.json` — from local `supabase/migrations/` directory

> **Do not manually edit these four files after 10.8.6A merges. They are robot-owned.**
> **Migration parity bumps are now automated. No separate manual step required.**

**Step 7 — Publish Truth Artifacts**

Run: `npm run handoff:commit` — commits and pushes truth artifacts on PR branch.

---

### Phase 3 — Verification

**Step 8** — Run semantic contract locally: `node scripts/ci_semantic_contract.mjs`

**Step 9** — If implementing a new gate, run it locally and confirm it passes before the green loop.

**Step 10** — Run: `npm run green:once` — must PASS.

**Step 11** — Run: `npm run green:twice` — must PASS. No edits between green:once and green:twice.

**Step 12** — Run: `npm run pr:preflight`

---

### Phase 4 — Proof

**Step 13** — Run the relevant gate. Save output to: `docs/proofs/<ITEM>_WORKING.log`
Iterate until gate output shows PASS. No non-proof changes between iterations.

**Step 14** — Rename to canonical form: `docs/proofs/<ITEM>_<UTC>.log`
Filename must exactly match the path allowlisted in Phase 1 Step 4.

**Step 15** — Finalize exactly once: `npm run proof:finalize docs/proofs/<ITEM>_<UTC>.log`

**Step 16** — Commit only:
- `docs/proofs/<ITEM>_<UTC>.log`
- `docs/proofs/manifest.json`

**Step 17** — Push (force-with-lease if branch diverged).

---

### Phase 5 — Review and Merge

**Step 18** — CI green → submit to QA with required evidence (see §5).

**Step 19** — QA returns APPROVE or REJECT.

**Step 20** — If APPROVE → merge to main.

---

### Phase 6 — Post-Merge Verification

**Step 21** — Run:
```
git checkout main
git pull
git status              → must show clean working tree
npm run pr:preflight    → must pass
npm run ship            → must PASS, zero diffs, exit 0
npm run handoff         → must produce zero diffs (idempotency check)
git status              → must still show clean working tree
```

**Step 22** — If `ship` or `handoff` fails on main after merge, enter Debugger Mode immediately.

---

### Phase 7 — DEVLOG

**Step 23** — DEVLOG entry is added **after merge**, in the next PR or a standalone governance PR.
DEVLOG is never part of the proof tail commit.

---

## 2) Completion Law (AUTHORITATIVE)

An objective is complete ONLY if:

PR opened → CI green → approved → merged

No PR = not complete
Local pass ≠ complete
"Nothing to commit" ≠ complete

One objective = One PR

No multi-objective PRs.

---

## 3) Proof-Only Work Rule

If an objective requires no functional code change:

A Proof PR is still required containing at least one:

- Committed proof artifact under `docs/proofs/**`
- pgTAP / invariant assertion

Proof must be:

- In-repo
- Commit-bound (PROOF_HEAD + scripts hash authority)
- CI validated (proof-manifest + proof-commit-binding)

Screenshots, pasted terminal output, or out-of-branch evidence are invalid.

---

## 4) Proof Artifact Rules (LOCKED)

**Objective:** Produce exactly **one final proof log per Build Route item**, bound to a tested commit, with a machine-managed manifest.

### 4.1 Core Rules

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

- `docs/proofs/**`

Any non-proof change after finalize is forbidden and requires restarting proof generation.

**Rule E — One canonical proof log per item per PR**
Iteration is allowed locally, but the PR must end with exactly **one canonical proof log** for the item.

**Rule F — proof:finalize runs a secret scan before writing**
`proof:finalize` scans the proof log for secret patterns (defined in `docs/truth/secret_scan_patterns.json`) before normalizing or writing to manifest. If any pattern matches, finalize exits non-zero, prints the pattern name and line number, and does NOT write to manifest. Redact the proof log before retrying.

**Rule F — STUB_GATES_ACTIVE block (mandatory while stubs active)**
If any gate listed in `docs/truth/deferred_proofs.json` remains active at the time of proof generation, the proof log must include a STUB_GATES_ACTIVE block immediately after the PR HEAD SHA line before proof:finalize is run. The block lists every active stub gate by name and conversion_trigger as recorded in deferred_proofs.json. Omitting this block when stubs are active is a proof authoring violation — restart proof generation. Authority: three-advisor review 2026-02-22.

**Rule G — Triple Registration for new truth files (HARD STOP)**
If a PR introduces any new file under `docs/truth/**`, it must be triple-registered once:
- Added to `scripts/ci_robot_owned_guard.ps1` protections
- Included in the truth-bootstrap validation gate
- Included in the handoff regeneration surface

---

### 4.2 Repair Protocol (If Proof/Manifest Is Broken)

If a proof/manifest mistake causes CI to go red (duplicate proof logs, stale manifest entry, or broken proof tail):

**Canonical repair (mechanical):**
1. Identify the last clean commit **before any proof/finalize/manifest changes** (`PREPROOF_HEAD`).
2. Reset the branch to `PREPROOF_HEAD` (discard the broken proof tail).
3. Fix the underlying objective/gate issue (non-proof work) until CI/local gates are green.
4. Generate the proof log again (canonical `<UTC>.log` only).
5. Run `npm run proof:finalize docs/proofs/<proof_log>.log` exactly once.
6. After finalize: proof-only tail commits only (`docs/proofs/**`).
7. Push.

**Do NOT** attempt to "prune" manifest entries via delete-first + re-finalize; `proof:finalize` does not prune and `ci_proof_manifest` will fail on stale entries.

---

## 5) QA Submission Rule (LOCKED)

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

## 6) Operating Modes

### 6.1 Executor Mode (Default)

Use when:

- Implementing a scoped Build Route item
- Producing required artifacts

Rules:

- One objective → one PR
- No redesign
- No debugging unless triggered

---

### 6.2 Debugger Mode (Triggered Only)

Enter Debugger Mode if ANY:

- A gate is red (local or CI)
- Same named gate fails twice
- A blocking error prevents required proof generation

Debugger Mode Rules:

- Identify first failing gate by name
- Fix that gate only
- Exit once green
- Do not redesign system
- Do not stack fixes

---

## 7) Execution Format (Session Rule)

Interactive step responses must follow the exact execution format defined in Command for Chat.

This governs session output only and does not alter documentation structure.

---

## 8) Shell Discipline (LOCKED)

Execution Shell Policy (Authoritative)

Default interactive shell on Windows is pwsh (PowerShell 7) for objectives involving:

- proof generation
- manifest updates
- file-writing scripts
- governance / CI scripts

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

- Do not switch shells mid-objective.
- If shell change is required due to instability, close or restart the objective and continue in the new shell.

Rationale:
Prevent encoding drift, line-ending corruption, and proof-binding failures.
Maintain deterministic auditability.

---

## 9) Proof-Commit-Binding Compliance

For all `docs/proofs/**` artifacts:

### 9.1 PROOF_HEAD

- Must equal tested SHA at runtime
- Must be ancestor of PR_HEAD
- Commits after PROOF_HEAD may modify only: `docs/proofs/**`

---

### 9.2 PROOF_SCRIPTS_HASH

Must be:

- Deterministic
- Explicit file list (no globbing)
- Deterministic ordering
- CRLF normalized to LF before hashing

Must match:

- AUTOMATION.md specification
- Validator implementation
- Proof log header

Mismatch = FAIL.

---

## 10) CI Lane Isolation (Policy)

Docs-only PR:
- Skip DB-heavy tests
- Run minimal gates only

Artifacts-only PR:
- Run drift + policy + proof-commit-binding
- Skip full DB suite

Code PR:
- Run full CI

If YAML does not enforce this, repository is noncompliant until corrected via objective PR.

---

## 11) Waiver Debt Enforcement (Build Route 2.16.4)

Waivers must be:

- Explicit
- Scoped
- Time-bounded
- Auditable

Expired waivers must fail CI.

Waiver removal requires:

PR opened → CI green → approved → merged

---

## 12) Stop Conditions (LOCKED)

Stop immediately if:

- Authoritative file missing
- CI red
- Unexpected file drift
- Build Route ambiguity

When a stop condition is triggered:

- Do not proceed with implementation
- Do not switch modes to bypass
- Do not redesign system
- Resolve the blocking issue first

---

## 13) Forbidden Actions

The following are prohibited:

- Hand-edit robot-owned files
- Commit directly to main
- Merge on red CI
- Open PR without required proof artifacts
- Merge without QA approval
- Multi-objective PRs
- Retro-edit historical migrations
- Introduce dynamic SQL in migrations
- Bypass proof artifact requirements
- Include DEVLOG in proof tail commit
- Modify a test to achieve a passing CI run without first correcting the underlying migration

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

- green:once
- green:twice

Both runs must pass with no edits between runs.

No generators may run during the gate loop.

---

## 16) Truth Artifact Rule (LOCKED)

Truth files are generated only via:

- `npm run handoff`
- `npm run handoff:commit`

`ship` is verify-only.

### Automated vs Manual Truth Files

| File | Authored by | Writer |
|---|---|---|
| `generated/schema.sql` | Robot | `handoff` |
| `generated/contracts.snapshot.json` | Robot | `handoff` |
| `docs/handoff_latest.txt` | Robot | `handoff` |
| `docs/truth/write_path_registry.json` | Robot | `handoff` |
| `docs/truth/tenant_table_selector.json` | Robot | `sync_truth_registries.mjs` via `handoff` |
| `docs/truth/definer_allowlist.json` | Robot | `sync_truth_registries.mjs` via `handoff` |
| `docs/truth/execute_allowlist.json` | Robot | `sync_truth_registries.mjs` via `handoff` |
| `docs/truth/cloud_migration_parity.json` | Robot | `sync_truth_registries.mjs` via `handoff` |
| `docs/truth/calc_version_registry.json` | Human | Manual (Phase 1 Step 3) |
| `docs/truth/rpc_contract_registry.json` | Human | Manual (Phase 1 Step 3) |
| `docs/truth/privilege_truth.json` | Human | Manual (Phase 1 Step 3) |
| `supabase/migrations/*.sql` | Human | Manual (Phase 1 Step 3) |
| `supabase/tests/*.test.sql` | Human | Manual (Phase 1 Step 3) |
| `docs/artifacts/CONTRACTS.md` | Human | Manual (Phase 1 Step 3) |
| `docs/governance/GOVERNANCE_CHANGE_*.md` | Human | Manual (Phase 1 Step 3) |

### When to run handoff

Run `handoff` + `handoff:commit` on the **PR branch, before merge**, when the PR changes anything that affects truth artifacts:

- Migration changes (`supabase/migrations/**`)
- Schema changes
- Contract changes (CONTRACTS.md or snapshot)
- Any change that would alter `generated/schema.sql`, `generated/contracts.snapshot.json`, or `docs/handoff_latest.txt`

Do NOT run handoff for governance-only PRs (CI wiring, docs, proof-only work) that do not touch the DB or contracts.

### Commit Sequence (LOCKED)

```
1. Write code/migrations/tests (Phase 1)
2. Verify tests pass locally (supabase test db)
3. Run npm run handoff (Phase 2)
4. Run npm run handoff:commit (Phase 2)
5. Commit — implementation + truth artifacts are now on branch
```

Migration parity bumps are automated via `handoff`. No separate manual step required.

### When to run ship

Run `ship` on **main, after merge**, as the post-merge verification step (see §1 Phase 6).

`ship` never generates. `ship` never commits. `ship` never pushes.

### When to run handoff on main

Run `handoff` on **main, after merge**, as the post-merge idempotency check (see §1 Phase 6).

On clean main with committed truth artifacts, `npm run handoff` must produce zero diffs. If it dirties the tree, the generators are nondeterministic — enter Debugger Mode.

### Summary

| Command | When | Branch | Writes files? |
|---|---|---|---|
| handoff | Before merge | PR branch | Yes (truth artifacts) |
| handoff:commit | Before merge | PR branch | Yes (commits + pushes artifacts) |
| ship | After merge | main only | No (verify-only) |
| handoff (idempotency) | After merge | main only | No (must produce zero diffs) |

---

## 17) Section Close Verification (LOCKED)

Before declaring a major section complete (e.g., Section 3, Section 4):

1. All items in the section have merged PRs with QA APPROVE.
2. DEVLOG entries exist for every item in the section.
3. On clean main after all merges, run full verification:

```
git checkout main
git pull
git status              → clean
npm run pr:preflight    → PASS
npm run ship            → PASS, zero diffs
npm run handoff         → zero diffs
git status              → still clean
npm run green:twice     → PASS
```

4. `docs/truth/required_checks.json` is current (no phantom or missing gates).

If any step fails, enter Debugger Mode before declaring the section closed.

Section close is recorded as a DEVLOG entry with format:

```
YYYY-MM-DD — Build Route vX.Y — Section N Closed

Objective
Changes
Verification evidence
Status
```

---

## 18) Known Gate Behaviors (Reference)

These gates are known to fire on conditions broader than their name implies.
When they fire unexpectedly, follow the prescribed fix — do not suppress or bypass.

### 18.1 ci_calc_version_lint (calc-version-registry gate)

**Trigger:** Any migration in the PR diff whose content contains a calc-logic token
(`calc_version`, `calc_versions`, `calculate_`, `compute_`, `pricing_`, `commission_`,
`fee_`, `rate_`) — even if the migration does not change calculation logic.

**Why it over-triggers:** The gate scans file content, not diffs of specific functions.
A migration that adds a column default of `calc_version = 1` or references a calc-adjacent
function will trigger the gate even if no calc logic changed.

**Prescribed fix:**
1. Bump the `version` field in `docs/truth/calc_version_registry.json`.
2. Add a `notes` entry explaining the migration touched calc-adjacent code without
   changing calc logic (e.g. "7.9: migration removed p_tenant_id from RPCs; incidentally
   contains calc_version column reference — no calc logic changed").
3. Commit alongside the migration in Phase 1.

**Do not:** leave the gate failing and fix in a separate commit after proof generation.

---

### 18.2 ci_entitlement_policy_coupling (entitlement-policy-coupling gate)

**Trigger:** Any PR where `generated/schema.sql` changes AND the file contains
`get_user_entitlements_v1` — which it always does, since the function is permanent.
Effectively fires on every PR that adds a migration (because every migration causes
`generated/schema.sql` to regenerate).

**Why it over-triggers:** The gate checks for presence of the entitlement function string
in the changed schema file, not whether the function body actually changed.

**Prescribed fix:**
1. Add a substantive note to `docs/artifacts/CONTRACTS.md` documenting what the PR
   changes at the behavioral/contract level (e.g. "no RPC accepts tenant_id as caller input").
2. The note must be real and accurate — not a placeholder to satisfy the gate.
3. Commit alongside the migration in Phase 1.

**Do not:** add a fake or empty CONTRACTS.md change purely to satisfy the gate.
The note must document something true about the PR's behavioral impact.

---
## 19) Test Seed Helper SOP

When adding or updating test-only seed helpers:

- Test seed helpers must be **internal only**
  - `SECURITY DEFINER`
  - fixed `search_path`
  - `REVOKE ALL FROM PUBLIC`
  - never granted to `authenticated`

- Test seed helpers may seed:
  - tenant/workspace
  - auth user
  - membership
  - active subscription
  - user profile current workspace

- Test seed helpers must be clearly **test-only**
  - not callable from app/runtime code
  - used only in pgTAP / local test setup

- **Do not use parameter names containing `tenant_id`**
  in SECURITY DEFINER test helpers, because catalog/audit tests may pattern-match
  `tenant_id` as caller-supplied tenancy input.

- Use test-safe parameter names instead, for example:
  - `p_seed_workspace`
  - `p_seed_ws`
  - `p_workspace_seed`

- If a new write-lock or entitlement rule requires common setup across many tests,
  prefer a reusable internal test seed helper over copy-pasting setup into many files.

- After adding a new test seed helper:
  1. run `supabase db reset`
  2. inspect the function definition in local DB if audit tests fail
  3. confirm no parameter names accidentally trip tenancy-input catalog audits


STATUS:
Aligned with Build Route v2.4
Aligned with AUTOMATION
Aligned with GUARDRAILS
Full procedure in §1
Proof-before-PR enforced
CI-green-before-QA enforced
QA-before-merge enforced
DEVLOG post-merge enforced
Stop conditions hardened
Execution surface stability enforced
Governance stack consistent
