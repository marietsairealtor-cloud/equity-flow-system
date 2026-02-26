# DEVLOG (Authoritative)

This file is the authoritative ledger of completed, proven work.
Entries are added **only when a gate is closed**.
If it is not logged here, it is not done.

---

## DEVLOG ENTRY FORMAT

## YYYY-MM-DD — Build Route vX.Y — Item

Objective  
- One sentence. What invariant, gate, or rule was established.

Changes  
- Mechanical description of what changed. No narrative.

Proof  

DoD  
- Bullet list copied from the Build Route item.

Status  
- PASS | FAIL

---

## 2026-02-07 — Build Route v2.4 — **1.1 Port Manifest (P0, Rebuild Mode)**

Objective  
Port all governance, tooling, docs, and scripts. No DB or schema porting.

Changes  
- Initialized new repo in REBUILD MODE  
- Ported governance artifacts, ops docs, threat docs, scripts  
- Added CODEOWNERS, CI workflows, handoff pointer  
- Enforced regenerate-only policy for generated outputs

Proof  
- docs/proofs/1.1_port_manifest_20260207_230957.log

DoD  
- Governance artifacts ported  
- No schema or DB artifacts present  
- Gate established

Status  
PASS

---

## 2026-02-07 — Build Route v2.4 — **1.2 Port Governance Runnable**

Objective  
Ensure ported governance and tooling are runnable and not dead-on-arrival.

Changes  
- Added package.json and npm scripts  
- Installed husky to satisfy prepare step  
- Added supabase/migrations placeholder  
- Fixed CI Node matrix (16+)  
- Added npm run ci

Proof  
- docs/proofs/1.2_port_governance_runnable_20260207_234238.log  
- docs/proofs/1.2_ci_green_20260207_235832.md

DoD  
- Governance scripts runnable  
- CI green on main

Status  
PASS

---

## 2026-02-08 — **1.3 Denylist Verification (P2)**

Objective  
Prove denylisted ghost-carrier paths are absent.

Changes  
- Added explicit denylist verification proof log

Proof  
- docs/proofs/1.3_denylist_20260208_002421.log

DoD  
- Denylisted paths absent  
- Verification commands recorded

Status  
PASS

---

## 2026-02-08 — **1.4 Regenerate-Only Policy (P3)**

Objective  
Prove no generated outputs were ported and regeneration is enforced.

Changes  
- Added regenerate-only policy proof log

Proof  
- docs/proofs/1.4_regen_policy_20260208_003105.log

DoD  
- No generated artifacts present  
- Generators exist and are enforced

Status  
PASS

---

## 2026-02-08 — **1.5 Document Corrections (Mandatory)**

Objective  
Correct publisher semantics and enforce encoding/BOM cleanliness.

Changes  
- Replaced “ship publishes” language  
- Fixed BOM/encoding regression  
- Verified INCIDENTS require no correction

Proof  
- docs/proofs/1.5_doc_corrections_fix_20260208_004544.md

DoD  
- Publisher semantics correct  
- Encoding gate passes

Status  
PASS

---

## 2026-02-08 — **2.1 Repo Bootstrap**

Objective  
Prove repo boots with pinned toolchain locally and in CI.

Changes  
- Added bootstrap proof logs  
- Captured CI summary proof

Proof  
- docs/proofs/2.1_repo_bootstrap_20260208_012254.md

DoD  
- Local npm ci succeeds  
- CI green  
- Toolchain versions recorded

Status  
PASS

---

## 2026-02-08 — **2.2 Toolchain Truth + Contract Gate**

Objective  
Pin and mechanically verify core toolchain (Node, npm, runner OS).

Changes  
- Added docs/truth/toolchain.json  
- Added scripts/check_toolchain.mjs and npm run toolchain:contract  
- Added merge-blocking CI workflow toolchain-contract

Proof  
- docs/proofs/2.2_toolchain_versions_20260208_145124.log

DoD  
- Toolchain truth file exists  
- CI hard-fails on mismatch

Status  
PASS

---

## 2026-02-08 — **2.3 Normalize Enforcement (renormalize-enforced)**

Objective  
Prevent Windows↔CI drift by enforcing renormalization checks.

Changes  
- Added scripts/check_renormalize.mjs  
- Added renormalize:check npm script  
- Added merge-blocking CI workflow renormalize-enforced

Proof  
- docs/proofs/2.2a_renormalize_enforced_20260208_163001.log

DoD  
- Gate exists and is deterministic  
- Fails if renormalization would introduce changes

Status  
PASS

---

## 2026-02-08 — **2.4 Branch Protection + Ruleset Enforced**

Objective  
Enforce PR-only merges to main with required checks and no admin bypass.

Changes  
- Created ruleset MAIN-BRANCH-RULES (ID 12578327)  
- Disabled admin bypass  
- Enforced required status check `required`  
- Verified via confirmation PR

Proof  
- docs/proofs/2.3_repo_rules_enforced_20260208_163125.md  
- docs/proofs/2.4_confirmation_20260208_142814.txt

DoD  
- Direct pushes to main rejected  
- Admin bypass disabled  
- Required check enforced

Status  
PASS

---

## 2026-02-08 — **2.5 Truth Bootstrap (Mandatory)**

Objective  
Bootstrap repo-truth inputs and enforce merge-blocking validation.

Changes  
- Added docs/truth/* inputs and schemas  
- Added truth-bootstrap validation script  
- Wired merge-blocking CI gate

Proof  
- docs/proofs/2.5_truth_bootstrap_20260208_231412Z.log

DoD  
- Truth inputs validated mechanically  
- CI blocks on failure

Status  
PASS

---

## 2026-02-08 — **2.6 Required Checks Contract (Merge-blocking)**

Objective  
Ensure required checks match CI workflow jobs exactly.

Changes  
- Added required_checks_contract.mjs  
- Removed lane-only checks from merge requirements  
- Wired merge-blocking gate

Proof  
- docs/proofs/2.6_required_checks_contract_20260208_232749Z.log

DoD  
- No phantom checks  
- No lane-only leakage

Status  
PASS

---

## 2026-02-08 — **2.7 Docs-only CI Skip Contract (Merge-blocking)**

Objective  
Ensure docs-only PRs skip DB-heavy jobs mechanically.

Changes  
- Added docs-only skip contract script  
- Updated CI workflow with paths-filter and gating  
- Added merge-blocking gate

Proof  
- docs/proofs/2.7_docs_only_ci_skip_20260208_234320Z.log

DoD  
- DB-heavy jobs skipped on docs-only PRs  
- Required checks still run

Status  
PASS

---

## 2026-02-09 — **2.8 Command Smoke (Gov-only)**

Objective  
Prove governance commands run without Supabase.

Changes  
- Added gov-only command smoke proof

Proof  
- docs/proofs/2.8_command_smoke_gov_20260209_142024Z.log

DoD  
- All 6 governance commands PASS on main without DB

Status  
PASS

---

## 2026-02-09 — **2.9 main-moved-guard**

Objective  
Enforce PR HEAD is up-to-date with origin/main.

Changes  
- Added ci_main_moved_guard.mjs  
- Added npm script and CI job  
- Enforced merge-blocking guard

Proof  
- docs/proofs/2.9_main_moved_guard_20260209_152822Z.log

DoD  
- PRs blocked if behind origin/main

Status  
PASS  
MAIN_HEAD=7606ef1 · CI/PR=#10
2026-02-09 — Docs: DEVLOG + archive non-referenced proofs
Objective
Archive non-referenced proof artifacts while keeping DEVLOG-referenced proofs in docs/proofs; prove PR-only governance still holds.
Changes
- Added docs/DEVLOG.md
- Moved non-referenced proofs into docs/proofs/_archive/
Proof
  green:twice PASS
  tests:
  - PR #11 merged; checks green
  schema:
  handoff:
  PR/CI: #11 (merge commit 0c18df2cc306a2acbe349d54bcb81a70ea6cac22)
DoD
- docs/proofs contains only proofs referenced by docs/DEVLOG.md
- docs/proofs/_archive contains older/unreferenced proofs
- Main branch remains governed by ruleset (required check = required; bypass = never)
Status
PASS

2026-02-09 — 2.10 Proof chain-of-custody + manifest

Objective
- Add proof chain-of-custody via SHA256 manifest + enforce append-only proofs.

Changes
- Added proof manifest verifier + proofs append-only guard.
- Updated docs/proofs/manifest.json after merge to include new proof log.

Proof
- docs/proofs/2.10_proof_manifest_20260209_184616Z.log
- docs/proofs/manifest.json

PR/CI
- PR: (fill after PR opened)
- MAIN_HEAD: 6cf2097
- DEVLOG_PR_HEAD: 5285a86

DoD
- manifest exists with SHA256 for in-scope proofs
- append-only enforcement gate present

Status
- CLOSED

2026-02-09 — Proof manifest canonicalization (post-merge doc closure)

Objective
- Record incident + guardrail and refresh proofs manifest after 2.11 merge.

Changes
- INCIDENTS: add proof-manifest self-entry/path normalization incident.
- GUARDRAILS: require POSIX proof-manifest keys.
- Regenerated docs/proofs/manifest.json to match repo state.

Proof
- npm run proof:manifest = PROOF_MANIFEST_OK (on PR branch)

PR/CI
- MAIN_HEAD (before): ac8d423
- PR_HEAD: 3c2c6b8

DoD
- Evidence captured; manifest consistent.

Status
- CLOSED

## 2026-02-09 — 2.12 Secrets discipline gate
Objective: Enforce repo-wide secrets scanning (including docs/proofs) as a merge-blocking gate.
Changes:
- Added CI gate: .github/workflows/secrets-scan.yml (Docker gitleaks; no org license dependency)
- Updated required checks truth to include: secrets-scan / secrets-scan
Proof:
- docs/proofs/2.12_secrets_scan_20260209_200749Z.log
- docs/proofs/2.12_secrets_scan_20260209_201208Z.log
- docs/proofs/2.12_secrets_scan_20260209_201409Z.log
PR/CI: #17 (merged); MAIN_HEAD=2a39434e08a220b1f52c046233f33d5cd475ba81
DoD: Secrets scan passes for repo + docs/proofs; proof includes scanner output + version; merge-blocking gate exists.
Status: PASS

## 2026-02-09 — 2.13 Environment sanity gate
Objective: Block clean-room actions on contaminated Docker/Supabase environments.
Changes:
- Added env sanity implementation: scripts/env_sanity.mjs (cross-platform)
- Added npm script: env:sanity
- Added CI job: CI / env-sanity (merge-blocking)
- Added required check truth: CI / env-sanity
Proof:
- docs/proofs/2.13_env_sanity_20260209_203725Z.log
- docs/proofs/2.13_env_sanity_20260209_204359Z.log
PR/CI: merged; MAIN_HEAD=5831fb4f0db449f0d6ca2fe412c81171b2696100
DoD: env:sanity passes clean; gate exists; required-checks-contract passes.
Status: PASS

## 2026-02-09 — 2.14 Stop-the-line incident coupling
Objective: Enforce explicit acknowledgment for stop-the-line failure classes (INCIDENT or one-PR waiver; mutual exclusivity).
Changes:
- Added gate script: scripts/stop_the_line_gate.mjs
- Added waiver location: docs/waivers/WAIVER_PR<NNN>.md (must contain: QA: NOT AN INCIDENT)
- Added merge-blocking CI gate: .github/workflows/stop-the-line.yml
- Added required check truth: stop-the-line / stop-the-line
Proof:
- docs/proofs/2.14_stop_the_line_20260209_205402Z.log
PR/CI: merged; MAIN_HEAD=f4933e6f9e866cc4b0ad169adc5b813de524911d
DoD: Gate blocks missing/dual ack; passes with exactly one; required-checks-contract PASS.
Status: PASS

## 2026-02-10 — 2.15 Governance-change guard

Objective:
Prevent governance drift via docs-only PRs.

Changes:
- Added governance-change guard enforcing PR-scoped justification.
- Forced non-docs lane when governance paths are touched.
- Documented incident, SOP, guardrails, and automation.

Proof:
- docs/proofs/2.15_governance_change_20260210_001959Z.log

PR/CI:
- PR #25 (guard implementation) — merged
- PR #26 (docs updates) — merged

DoD:
- Governance-touch requires justification.
- Docs-only override enforced.
- CI merge-blocking gate active.

Status: CLOSED
## 2026-02-10 — Section 2 Close — Governance only (2.1–2.15)

MAIN_HEAD: 82add418fa0542215ca7a73dacb7a203d88d571b

Post-merge governance verification completed on main.
All Section 2 governance gates were re-run locally on a clean tree and returned PASS.
No DB, no publish step, no runtime artifacts involved.

What ran (gov-only close):
- npm run preflight:encoding
- npm run renormalize:check
- npm run required-checks-contract
- npm run docs-only-ci-skip

Status: CLOSED

## 2026-02-10 — Section 2 Audit Review (Advisor Meeting)

Objective
Validate residual risk in Section 2 (Governance/Foundation) and identify additive hardening only, without reopening or resequencing closed work.

Context
Section 2 is closed and frozen. Review was audit-only (risk, silent failure modes, future-proofing). No redesign permitted.

Findings (Consensus)
- Governance is internally consistent and sufficient to proceed.
- Primary residual risks are:
  - External platform drift (GitHub rulesets / permissions changing while CI stays green).
  - CI semantic rot (checks becoming no-ops with unchanged names).
  - Proof validity gaps (proofs correct but bound to wrong reality).
  - Human erosion (waivers, justifications degrading under pressure).
- No missing prerequisite blocks Section 3.
- Section 3 (Security) is the correct next focus.

Decisions — Additive Hardenings Approved
- 2.16.1 — GitHub Policy Drift Attestation: Keep as-is (scheduled, alert-level signal for platform drift).
- 2.16.2 — Proof Commit-Binding: Keep as-is (bind proofs to PR HEAD + script hash).
- 2.16.3 — CI Semantic Contract: Implement with hard-fail only when .github/workflows/** changes; alert-only otherwise.
- 2.16.4 — Negative-Space Proof Assertion: Dropped (overkill / high ceremony).
- 2.16.5 — Waiver Rate-Limit Enforcement: Downgraded (alert-only with very low ceiling; hard-fail only on abuse patterns).
- 2.16.6 — Governance-Change Justification Quality: Keep minimal (enforce structure + non-empty fields only).

Non-Decisions
- No changes to existing gates.
- No renumbering of Section 2.
- No guardrail reinterpretation.
- No movement of items into Section 3.

Outcome
- Section 2 remains closed and authoritative.
- Additive hardening items approved for future implementation.
- Proceed to Section 3 (Security).

Status
Advisory review complete. Evidence recorded. No action required to close Section 2.

## 2026-02-10 — Close 2.16.1 GitHub Policy Drift Attestation

Objective  
Close **2.16.1 — GitHub Policy Drift Attestation** with a QA-verified proof, resolving prior proof/HEAD ambiguity without reopening Section 2 or changing governance intent.

Context  
Initial attempts exposed ambiguity in the meaning of `HEAD` within proof logs (tested commit vs. commit storing the proof), causing repeated PR churn. QA clarified the contract to align with operational reality while preserving rigor.

Clarified Proof Contract (QA-approved)  
- `HEAD` denotes the **commit that was tested**.
- Proof is committed **after** execution.
- Acceptance requires:
  - `HEAD` is an **ancestor** of PR/merge commit.
  - All diffs after `HEAD` are **proof-only** (`docs/proofs/**`).
- No CI self-commit or amend required.

Execution  
- Proof generated on PR branch against tested commit.
- Proof log includes:
  - `UTC=`
  - `BRANCH=`
  - `HEAD=<tested commit>`
  - GitHub API HTTP evidence
  - Terminal `OK` signal.
- Proof committed once; superseded proof artifacts cleaned up.
- PR merged cleanly to `main`.

Evidence  
- Merge commit: `32d14c7` (PR #33).
- Tested commit: `bb00ecf`.
- Proof artifact:  
  `docs/proofs/2.16.1_policy_drift_attestation_20260210_185039Z.log`
- QA verification:
  - `git merge-base --is-ancestor bb00ecf 32d14c7` → OK
  - `git diff bb00ecf..32d14c7` → `docs/proofs/**` only

Outcome  
- **2.16.1 CLOSED**.
- Section 2 governance remains frozen and authoritative.
- Proof binding semantics now explicit, eliminating future treadmill risk.

Status  
Closed. QA PASS. No further action required.

## 2026-02-11 — 2.16.2A — PROOF_SCRIPTS_HASH Authority Contract

### Objective

Eliminate drift between documentation and validator logic for `PROOF_SCRIPTS_HASH` by establishing a single authoritative declaration and enforcing deterministic hashing + proof binding discipline.

---

### Changes

**1. Authority Declaration (docs/artifacts/AUTOMATION.md)**

* Added section:




* Declared:

* Explicit script file list (no globbing)
* Ordering rule (list order)
* UTF-8 (no BOM) requirement
* CRLF → LF normalization
* Hash framing:

  * `FILE:<relpath>\n`
  * normalized file text
  * `\n`
* SHA-256 → lowercase hex
* Locked parser contract (start marker + expected bullet structure + end marker)

**2. Validator Enforcement**

* `ci_proof_commit_binding.ps1` now:

* Parses authority section
* Extracts script list deterministically
* Normalizes in-memory before hashing
* Emits:

  * PROOF_SCRIPTS_FILES
  * PROOF_SCRIPTS_FILE_SHA256
  * PROOF_SCRIPTS_HASH
* Rejects drift

**3. Manifest Hardening**

* Absolute-path key existed in historical proof state (`dd38caa`).
* Current manifest contains **no** absolute paths; keys are repo-relative under `docs/proofs/`.
* JSON validity confirmed.

**4. Proof Binding Discipline**

* Enforced rule:

* Non-proof commit first
* Proof commit second
* After proof commit → only `docs/proofs/**` may change
* Validator correctly triggers `POST_PROOF_NON_PROOF_CHANGE` on violation.
* Proof log contract tightened:

* `PROOF_HEAD` must be full 40-hex
* Proof binding constraints are validator-enforced

---

### Proof

* Authority header UTF-8 verified (E2 80 94 em-dash).
* No mojibake bytes.
* Manifest:

* Historical absolute-path key confirmed in `dd38caa`
* HEAD manifest confirms **no** absolute paths
* All keys repo-relative
* Gate output:

* Proof log recorded:


---

### DoD (Definition of Done)

* [x] Authority declared exactly once.
* [x] Script list string-exact.
* [x] Validator implements declared contract exactly.
* [x] Hash normalization deterministic.
* [x] Manifest keys repo-relative only.
* [x] Proof log uses 40-hex `PROOF_HEAD`.
* [x] Proof binding validated by CI gate.
* [x] CI returns success.

---

### Status

**COMPLETE — PASS — MERGED**

Governance maturity increased.  
Drift vector closed.  
Hash authority deterministic.

---

## 2026-02-11 — Build Route v2.4 — Governance Hardening (2.16.6–2.16.11)

**Objective**

Add structural governance enforcement after repeated CI topology drift, proof discipline violations, waiver ambiguity, and silent workflow/artifact mutations.

**Why This Section Was Added**

Evidence showed governance surface (truth files, workflows, required checks, artifacts) could mutate without explicit declaration, and CI could pass despite structural drift. Repeated PRs bundled governance + functional changes without trace artifacts.

The 2.16.6–2.16.11 block formalizes enforcement to prevent recurrence and slow governance mutation rate.

**Items Introduced**

* **2.16.6 — Lane Policy Truth**
  → Define merge-blocking vs lane-only checks in machine-readable truth.

* **2.16.7 — Lane Enforcement Gate**
  → Enforce declared lane policy in CI.

* **2.16.8 — Stop-the-Line XOR Gate**
  → Require exactly-one acknowledgment artifact when stop-the-line triggers (INCIDENT xor WAIVER).

* **2.16.9 — Waiver Policy Truth + Rate Limit**
  → Prevent silent waiver debt accumulation.

* **2.16.10 — Robot-Owned File Guard**
  → Block unauthorized edits to protected governance artifacts.

* **2.16.11 — Governance-Change Template Contract**
  → Require explicit declaration (`GOVERNANCE_CHANGE_PR<NNN>.md`) when governance surface is modified.

---

**2026-02-11 — Build Route v2.4 — Section 2.17 Ported Files Stability Sweep**

**Objective**
Restore and harden determinism after PS5→PS7 port and validator brittleness surfaced encoding, newline, path-leak, and parsing fragility.

**Changes**

* Added 2.17.1 Repository Normalization Contract
* Added 2.17.2 Encoding & Hidden Character Audit (block on forbidden classes only)
* Added 2.17.3 Absolute Path / Machine Leak Audit (scoped blocking)
* Added 2.17.4 Parser Contract Resilience Check (fixture-based, hash-of-normalized-output comparator)

**Proof**
Governed via CI gates: `ci_normalize_sweep`, `ci_encoding_audit`, `ci_path_leak_audit`, `ci_validator` (fixture pack).

**DoD**
All four sweeps implemented, produce proof logs under `docs/proofs/`, and pass CI with deterministic output.

**Status**
LOCKED (additive hardening; no runtime expansion).

2026-02-11 — 2.16.3 — CI Semantic Contract (Targeted Anti–No-Op)
Deliverable
- Semantic validation that required CI jobs actually execute gates.

DoD
- If .github/workflows/** changes in PR:
  * semantic contract is merge-blocking
- Otherwise:
  * runs alert-only (PR + scheduled)
- Validator asserts required jobs:
  * invoke allowlisted gate scripts
  * are not noop / echo-only exits

Proof
- docs/proofs/2.16.3_ci_semantic_contract_20260211_180456Z.log

Gate
- ci-semantic-contract
(merge-blocking only on workflow changes)


2026-02-11 — Build Route v2.16.4A — waiver-debt-enforcement CI wiring
Objective
Wire waiver-debt-enforcement into CI and make it merge-blocking via the required aggregate gate.
Changes
- .github/workflows/ci.yml: add job waiver-debt-enforcement (checkout fetch-depth: 0, Node 20, run scripts/waiver_debt_enforcement.mjs)
- .github/workflows/ci.yml: required.needs includes waiver-debt-enforcement
Proof
- Merged on main: commit 56c6719 (PR #55)
- CI on 56c6719 shows CI / waiver-debt-enforcement and CI / required passing
DoD
waiver-debt-enforcement runs in CI and is enforced via required.needs.
Status
Merged


---


2026-02-12 — Build Route v2.4 — Additive Hardening Items (2.16.4A–2.16.4C, 2.17)

Objective
Add additive governance hardening to prevent: silent CI topology drift (“phantom gates”); truth file drift from human maintenance; ported-file instability (PS5→PS7 newline/encoding/path leak/parsing brittleness). Scope is additive only; Section 2 remains frozen; no resequencing.

Changes
1) 2.16.4A — CI Gate Wiring Closure (Authoritative)
- Intent: close wiring gaps by making truth/required_checks.json authoritative and ensuring:
  - each truth entry exists as a workflow job ID (string-exact)
  - aggregate required.needs includes the full truth set (string-exact)
- Artifacts: docs/proofs/2.16.4A_ci_gate_wiring_closure_<UTC>.log
- Gate: ci-gate-wiring-closure (merge-blocking)

2) 2.16.4B — CI Topology Audit Gate (No Phantom Gates Enforcement)
- Intent: prevent drift by asserting:
  - truth → workflows: every truth-required gate exists as a job ID in .github/workflows/**
  - truth → merge-block topology: required.needs includes the full truth set
  - docs/package scripts are non-authoritative unless workflow-wired
- Artifacts: docs/proofs/2.16.4B_ci_topology_audit_<UTC>.log
- Gate: ci-topology-audit (merge-blocking)

3) 2.16.4C — Truth Sync Enforcement (Machine-Derived Truth)
- Intent: eliminate manual drift by requiring:
  - npm run truth:sync deterministically regenerates truth/required_checks.json
  - CI fails if truth:sync produces any diff (git diff --exit-code)
  - running twice produces identical output
- Artifacts: docs/proofs/2.16.4C_truth_sync_<UTC>.log
- Gate: truth-sync-enforced (merge-blocking)

4) 2.17 — Ported Files Stability Sweep (Authoritative)
- Intent: stabilize ported files and parser behavior after PS5→PS7 port:
  - normalization determinism (LF/no-BOM) for governed paths
  - forbidden character sweep (BOM/zero-width/control)
  - absolute path leakage audit (blocking only in high-risk outputs)
  - validator parser robustness via adversarial fixture pack + normalized-output hash comparator
- Items:
  - 2.17.1 Repository Normalization Contract (ci_normalize_sweep)
  - 2.17.2 Encoding & Hidden Character Audit (ci_encoding_audit)
  - 2.17.3 Absolute Path / Machine Leak Audit (ci_path_leak_audit)
  - 2.17.4 Parser Contract Resilience Check (ci_validator fixture pack)
- Proofs:
  - docs/proofs/2.17.1_normalize_sweep_<UTC>.log
  - docs/proofs/2.17.2_encoding_audit_<UTC>.log
  - docs/proofs/2.17.3_path_leak_audit_<UTC>.log
  - docs/proofs/2.17.4_parser_fixture_check_<UTC>.log

Proof
Additive Build Route additions only (authoritative requirements). No implementation proof in this entry.

DoD
Addendum items recorded without resequencing; Section 2 remains frozen; requirements are additive only.

Status
Approved for staged implementation: start 2.16.4A → 2.16.4B → 2.16.4C, then 2.17.

2026-02-12 — Build Route v2.4 — 2.16.4B CI Topology Audit Gate (No Phantom Gates)

Objective
Implement merge-blocking CI topology audit to prevent silent governance drift by validating truth-required checks exist in workflows and that CI aggregation is wired correctly.

Changes
- Added scripts/ci_topology_audit.mjs (YAML-parse; derives <workflow.name> / <job.name||jobId>; validates truth membership; validates required.needs for CI truth job IDs).
- Added CI job ci-topology-audit and wired into required.needs in .github/workflows/ci.yml.
- Added devDependency yaml to package.json to support deterministic YAML parsing.

Proof
- docs/proofs/2.16.4B_ci_topology_audit_20260212_163106Z.log

DoD
- CI green.
- Merge-blocking gate ci-topology-audit present and aggregated via required.needs.
- Proof log includes PROOF_HEAD and PROOF_SCRIPTS_HASH.

Status
PASS — PR #59 (https://github.com/Equity-Flow-Systems/equity-flow-system/pull/59)


---


## 2026-02-12T15:45:31Z — Build Route 2.16.4A — CI Gate Wiring Closure (Required Checks + Policy Ruleset Snapshotting)

### Objective
Close CI aggregate-gate gap by ensuring:
- All truth-required checks are present in workflow job IDs (string-exact).
- All truth-required checks are wired into `jobs.required.needs`.
- Branch ruleset required checks are captured in policy drift snapshot.
- Proof binding remains commit-ancestor constrained.

### Changes
- Updated `.github/workflows/ci.yml`:
  - Added missing required jobs to `jobs.required.needs`.
- Updated `docs/truth/required_checks.json`:
  - Marked `CI / waiver-debt-enforcement` as `required: true`.
- Enhanced `scripts/policy_drift_attest.mjs`:
  - Extract required status checks from rulesets (not only branch protection).
- Added proof:
  - `docs/proofs/2.16.4A_ci_gate_wiring_closure_20260212_153352Z.log`

### DoD
- `required-checks-contract` PASS
- `ci_proof_commit_binding.ps1` PASS
- CI GREEN
- Diff limited to:
  - .github/workflows/ci.yml
  - docs/truth/required_checks.json
  - scripts/policy_drift_attest.mjs
  - docs/proofs/2.16.4A_ci_gate_wiring_closure_*.log

Status: COMPLETE ✅


---

## 2026-02-12 — Build Route v2.4 — **2.16.4B CI Topology Audit Gate (No Phantom Gates Enforcement)**

Objective  
- Implement merge-blocking CI topology audit to prevent silent governance drift by validating truth-required checks exist in workflows and CI aggregation wiring is correct.

Changes  
- Added `scripts/ci_topology_audit.mjs` (YAML parse; derives `<workflow.name> / <job.name||jobId>`; validates truth membership; validates `required.needs` contains CI truth job IDs).
- Added `ci-topology-audit` job to `.github/workflows/ci.yml` and wired it into `required.needs` (merge-blocking via aggregate).
- Added `yaml` as a dev dependency in `package.json` to support deterministic YAML parsing.

Proof  
- `docs/proofs/2.16.4B_ci_topology_audit_20260212_163106Z.log`

DoD  
- `ci-topology-audit` runs on `pull_request`.
- Loads required check names from `docs/truth/required_checks.json`.
- Asserts truth-required checks exist as workflow-derived check names.
- Asserts `.github/workflows/ci.yml` job `required` exists and `required.needs` includes the CI truth job IDs.
- Gate `ci-topology-audit` is merge-blocking.

Status
- PASS — PR #59


## 2026-02-12 — Build Route v2.4 — **2.16.4C Truth Sync Enforced (CI-only required checks)**

Objective
- Define “required” as CI-topology only (derived from `ci.yml:required.needs`) and enforce regen-invariant via merge-blocking truth sync.

Changes
- Added `truth-sync-enforced` job to `.github/workflows/ci.yml` and wired into `jobs.required.needs`.
- Added generator `scripts/truth_sync_required_checks.mjs` and `npm run truth:sync` to deterministically rewrite `docs/truth/required_checks.json`.
- Updated `scripts/ci_semantic_contract.mjs` allowlist to permit `npm run truth:sync` gate.
- Updated proof manifest entries for new proof logs.

Proof
- docs/proofs/2.16.4C_truth_sync_20260212_193531Z.log
- docs/proofs/2.16.4C_truth_sync_20260212_205811Z.log

DoD
- `truth:sync` deterministically rewrites CI-only truth from `required.needs` (sorted; UTF-8; trailing newline).
- Idempotent: two consecutive `truth:sync` runs produce no diff (`git diff --exit-code`).
- Merge-blocking gate `truth-sync-enforced` runs `npm run truth:sync && git diff --exit-code`.
- `truth-sync-enforced` included in `jobs.required.needs`.

Status
PASS


## 2026-02-12 — Build Route v2.4 Update — Wholesale Hub Integration

Objective
- Extend Build Route v2.4 (Rebuild Mode) to explicitly support Free MAO Calculator → Per-Seat Wholesale Hub (USD, single tier) without altering stack (Supabase + WeWeb) or weakening governance guarantees.

Changes
- Added Build Route items: Section 6 (6.6–6.8), Section 7 (7.4–7.5), Section 10 (10.3–10.6), Section 11 (11.8–11.9).
- Preserved invariants: RLS day one, calc_version persisted, idempotent server-side writes, merge-blocking security gates; no enterprise CRM scope.

Proof
- N/A (Build Route update only)

DoD
- Build Route v2.4 updated with listed items
- No locked-section edits outside intended insertion points

Status
PASS

---

## 2026-02-12 — Build Route Extension — 2.16.5A–2.16.5G (Foundation/Product Split)

Objective
- Extend Build Route v2.4 after 2.16.5 to formally separate Foundation (shared platform layer) from Product/UI (fork-specific layer) to support multi-product reuse without weakening governance.

Changes
- Added items 2.16.5A–2.16.5G immediately after 2.16.5; downstream numbering unchanged.
- Defined boundary contract, repo layout separation, invariants suite, lane separation enforcement, versioning/fork protocol, anti-divergence detector, product scaffold generator.

Proof
- N/A (Build Route update only)

DoD
- Build Route v2.4 updated with items listed above
- No modifications to locked sections prior to 2.16.5

Status
PASS


## 2026-02-12 — Advisor Review Outcome (Feb 11–12 additions) — Scope/Alignment OK

Objective
- Confirm no scope creep; increase governance density only where aligned; mechanically freeze Section 2 against speculative hardening.

Changes
- Classified gating items as merge-blocking vs lane-only vs dormant (effective immediately).
- Declared Section 2 “Stop rule” to prevent further meta-governance expansion without incident-based justification.

Proof
- N/A (advisor review / classification entry)

DoD
- Decision recorded in DEVLOG
- Gating classification captured
- Section 2 freeze rule captured
- Next execution section declared

Status
PASS

### Decision
No scope creep. Governance density increased but remains aligned. Section 2 is now mechanically frozen.

### Gating classification (effective immediately)

MERGE-BLOCKING NOW (core integrity / anti-drift / reproducibility)
- 2.16.2A — PROOF_SCRIPTS_HASH authority
- 2.16.3 — CI Semantic Contract
- 2.16.4A — waiver-debt-enforcement wiring
- 2.16.4B — CI Topology Audit
- 2.16.4C — Truth Sync Enforced
- 2.17.1 — Repo Normalization (block only on real violations)
- 2.17.2 — Encoding/hidden char audit (block only on forbidden classes)
- 2.17.3 — Absolute path / machine leak audit (block only on real leaks)

LANE-ONLY (alert-first; promote only if it catches real corruption)
- 2.17.4 — Parser resilience check (fixture-based)

DORMANT (defined in Build Route; NOT enforced until Hub/Billing scope)
- 6.6–6.8, 7.4–7.5, 10.3–10.6, 11.8–11.9 (Wholesale Hub ranges)
- 2.16.5A–2.16.5G (Foundation/Product split suite)

### Stop rule (Section 2 Freeze)
No new meta-governance items unless:
(a) a real incident exposes a bypass/gap (post-mortem required), OR
(b) Section 3/6 implementation proves a missing invariant that cannot be solved without governance change.
No speculative hardening.

Next
Proceed to Section 3 (Automation Build). No further Section 2 additions without meeting the stop rule.


## 2026-02-13 — Build Route v2.4 — 2.16.5 Governance-Change Justification (Human Contract)

Objective  
Clarify 2.16.5 as a reviewer-discipline specification only (no new CI gate, no new required check), triggered solely when governance surface changes.

Changes  
- Updated 2.16.5 section in:
  docs/artifacts/Build Route v2.4 - Rebuild Mode.md
- Confirmed no new workflows, required checks, or enforcement scripts added.
- Bound proof artifact with PROOF_HEAD + PROOF_SCRIPTS_HASH.

Proof  
docs/proofs/2.16.5_governance_change_justification_20260213_010644Z.log  
Gov-only local gate pack PASS  
CI green including proof-commit-binding PASS  
Post-merge verify-only on main clean (truth:sync no diff)

DoD  
PR opened → CI green → approved → merged  
Post-merge verify-only gates PASS on main  
Working tree clean  

Status  
MERGED


## 2026-02-13 — Build Route v2.4 — 2.16.5A Foundation Boundary Contract (Scope Tighten)

Objective  
Tighten 2.16.5A to explicitly define Foundation as governance + core DB security layer and clarify enforcement is via existing governance gates + human review (no new gate introduced).

Changes  
- Updated wording in:
  docs/artifacts/Build Route v2.4 - Rebuild Mode.md
- Clarified:
  * Foundation = governance + core DB security layer
  * Product must not weaken Foundation invariants
  * No new CI gate added
- No enforcement logic, required checks, or CI topology modified.

Proof  
Docs-only PR  
CI green  
Incident recorded for prior process order violation  
Post-merge verify-only gates PASS

DoD  
PR opened → CI green → QA PASS → merged  
Working tree clean on main  

Status  
MERGED

## 2026-02-13 — Build Route v2.16.5 — Proof Manifest Reset

### Objective
Return the repository to a stable baseline for 2.16.5 before setting up the proof manifest.

### Rationale
- Multiple proof artifacts (2.16.5A/B and _archive files) were inconsistent, misnamed, or missing in the manifest.
- Previous attempts to reconcile hashes and PROOF_HEADs across commits had caused conflicts, MISSING PROOF_HEAD, and MANIFEST_INVALID errors.
- Resetting to **PR 66**, the commit where 2.16.5 was finalized and the DEVLOG recorded, ensures a **clean, authoritative starting point**.
- Provides a deterministic foundation to correctly create or update the proof manifest without conflicts from later, partial, or uncommitted changes.

### Status
Repo now reflects the state immediately after 2.16.5 completion.
All proof files and DEVLOG entries align with this baseline.
Ready to begin generating the proof manifest.


## 2026-02-14 — Build Route v2.16.5 — Proof-Manifest CI Gate

### Objective
Add and enforce the `proof-manifest` CI job as a required status check for 2.16.5 proof artifacts.

### Changes
- Created `proof-manifest` job in `.github/workflows/ci.yml`.
- Added `proof-manifest` to the aggregate `required` job so it acts as a merge-blocking gate.
- Updated `docs/truth/required_checks.json` to include `CI / proof-manifest`.
- Regenerated all SHA256 hashes in `docs/proofs/manifest.json` to ensure consistency.
- Verified all 2.16.5 proof artifacts (2.16.5A, 2.16.5B, and `_archive` logs) are correctly referenced and pass hash validation.
- PR merged, CI verified, repo stable.

### Proof
- `ci_proof_manifest.ps1` execution confirms all artifacts and hashes are correct.
- `npm run truth:sync` verifies `required_checks.json` matches CI workflow jobs.

### Status
- Repo fully validated and CI-gate for proof-manifest is active.
- Ready for next objectives in Build Route 2.16.5 follow-up.

## 2026-02-14 — Build Route v2.16.5A — Foundation Boundary Contract

### Objective

Define the authoritative boundary between Foundation (governance + core DB security layer) and Product/UI, per Build Route 2.16.5A DoD.

### Changes

- Added docs/artifacts/FOUNDATION_BOUNDARY.md defining owned surfaces (Foundation vs Product/UI) and enforcement intent (gates).
- Added 2.16.5A proof log and updated proof manifest.

### Proof

- docs/proofs/2.16.5A_foundation_boundary_contract_20260214_141255Z.log

### DoD

- Boundary documented in docs/artifacts/FOUNDATION_BOUNDARY.md.
- Foundation ownership list includes: tenancy model, memberships+roles, entitlement truth, activity log contract, baseline RLS + negative tests, core CI contracts/proofs.
- Product/UI ownership list includes: product domain tables, WeWeb pages/flows, product-specific views/functions extending baseline (must not weaken Foundation invariants).
- Proof recorded and docs/proofs/manifest.json updated (repo-relative POSIX paths; valid JSON).

### Status

- MERGED to main via PR #89.
- Local verification on main: 
pm run required-checks-contract PASS; 
pm run proof:manifest PASS; working tree clean.

---

2026-02-14 — Governance Maintenance — proof-commit-binding Windows Parse Hardening

Objective
Fix Windows PowerShell parse failure in scripts/ci_proof_commit_binding.ps1 caused by non-ASCII em dash in authority header string, without changing governance semantics.

Changes
- Hardened header marker construction using explicit Unicode char ([char]0x2014).
- Added governance record: docs/governance/GOVERNANCE_CHANGE_PR004.md.
- Generated and manifest-bound proof artifact.

Proof
- docs/proofs/fix_proof_commit_binding_windows_parse_20260214_220325Z.log
- proof:manifest → PROOF_MANIFEST_OK
- proof:commit-binding → PROOF_COMMIT_BINDING_OK
- CI green prior to merge.

DoD
PR opened → CI green → QA APPROVE → merged.
Post-merge: main clean; proof gates green.

Status
Merged.

## 2026-02-14 — Build Route v2.16.5C — Foundation Invariants Suite

Objective
- Add foundation invariants runner + CI wiring; safe BLOCKED mode until foundation schema exists.

Changes
- Added 
pm run foundation:invariants runner + deterministic stubs under supabase/foundation/invariants/
- CI job oundation-invariants (triggered by supabase/foundation/**) + required-checks truth sync
- ci-semantic-contract allowlist updated for 
pm run foundation:invariants
- Governance change doc added (CI behavior change)

Proof
- docs/proofs/2.16.5C_foundation_invariants_suite_2026-02-14_1805.log (BLOCKED exit-0 mode)
- docs/proofs/manifest.json updated

DoD
- Runner prints BLOCKED_NO_FOUNDATION_SURFACE, sets FOUNDATION_INVARIANTS_BLOCKED=1, exits 0 when schema missing

Status
- MERGED (PR: pr/2.16.5C-foundation-invariants). BLOCKED — pending foundation schema surface (item 6.9).

## 2026-02-15 — Build Route v2.16.5D — CI Lane Separation Enforcement

**Objective**: Implemented lane separation for Foundation and Product/UI in CI configuration.

**Changes**:
- Updated `.github/workflows/ci.yml` to enforce lane separation between Foundation and Product/UI changes.
- Adjusted `docs/proofs/2.16.5D_lane_separation_enforcement_2026-02-15.log` to reflect the correct proof hash.
- Added proper lane rules and conditions to ensure that Foundation changes trigger the required checks, and Product/UI changes skip Foundation gates.
- Edited `docs/proofs/manifest.json` to include the new proof file entry.

**Proof**:
- `docs/proofs/2.16.5D_lane_separation_enforcement_2026-02-15.log` — Proof file generated to validate lane separation logic.

**DoD**: 
- CI passes with all relevant gates triggered.
- Foundation changes run required checks: **Invariant + RLS-negative + stop-the-line + ci-topology-audit**.
- Product/UI changes skip Foundation checks and only run Product lane checks + **ci-topology-audit**.

**Status**: Completed and merged. All checks are green, and validation through two PRs (Foundation and Product-only) was successful.


## 2026-02-15 — Proof Finalize Command (Tooling Hardening)

Objective: Eliminate Windows proof-manifest / proof-commit-binding friction by providing a single deterministic finalize command.

Implemented
Added scripts/proof_finalize.ps1.
Added npm run proof:finalize.

Command now:
normalizes proof logs to UTF-8 (no BOM) + LF
injects PROOF_HEAD + scripts hash authority headers
updates docs/proofs/manifest.json
runs proof validators locally.

Proof
docs/proofs/test_proof_log_2026-02-15.log
CI: proof-manifest ✅, proof-commit-binding ✅ (ALL GREEN).

Outcome: Proof workflow reduced to one command; prevents recurring hash/binding failures.

### 2.16.X — PR Preflight Command (Governance Hardening)

Objective:
Reduce avoidable CI-red outcomes by adding a deterministic local preflight check before opening PRs.

Implemented:
- Added `scripts/pr_preflight.ps1`.
- Added `npm run pr:preflight`.
- Preflight now runs governance-safe local checks:
  - encoding preflight
  - toolchain contract
  - truth sync (if present)
  - proof manifest validation
  - proof commit binding validation

Notes:
- `pr:preflight` is verification-only and does NOT modify files.
- Proof artifact mutation remains handled exclusively by:
  - `npm run proof:finalize -- -File docs/proofs/<proof_log>.log`

Outcome:
Operators can run one command before PR creation to catch most governance/proof failures locally, reducing CI reruns and workflow detours.

2026-02-15 — Build Route v2.4 — 2.16.5E

Objective
Foundation versioning + fork protocol (tagging, product pinning, upgrade rules) recorded as governed proof.

Changes
- Protocol recorded in proof logs (commit-binding policy required proofs-only).
- No DB scope.

Proof
docs/proofs/2.16.5E_foundation_fork_protocol_20260215_212411Z.log

DoD
PR opened → CI green → QA approved → merged; ship PASS; clean tree.

Status
PASS

2026-02-15 — Build Route v2.4 — 2.16.5F

Objective
Implement Anti-Divergence Drift Detector wired into existing stop-the-line gate.

Changes
- Added scripts/foundation_drift_detector.mjs
- Patched scripts/stop_the_line_gate.mjs to derive FAILURE_CLASS=FOUNDATION_DRIFT
- Updated ci.yml stop-the-line checkout to fetch-depth: 0
- Added proof log + manifest update

Proof
docs/proofs/2.16.5F_foundation_drift_detector_.log

DoD
- Drift detection triggers stop-the-line on foundation path edits
- No new required check added
- CI / required green
- proof-manifest + proof-commit-binding green

Status
MERGED


2026-02-15 — Build Route v2.4 — Governance Hardening (pwsh enforcement)

Objective
Force proof:finalize to run under pwsh to prevent Windows PowerShell incompatibility.

Changes
- Updated package.json script proof:finalize to use pwsh.

Proof
PR #115

DoD
- npm run proof:finalize invokes pwsh
- Get-FileHash available
- CI green

Status
MERGED

2026-02-15 — Build Route v2.4 — 2.16.5G

Objective
Implement Product Scaffold Generator for Foundation/Product split.

Changes
- Added scripts/product_scaffold.mjs
- Wired npm script: product:scaffold
- Generated proof 2.16.5G_product_scaffold_generator_<UTC>
- Updated proof manifest
- Rebound PROOF_HEAD to final functional commit

Proof
docs/proofs/2.16.5G_product_scaffold_generator_20260215T230253Z.log

DoD
Scaffold creates deterministic product shell under products/<name>, fails on re-run, CI green, QA approved, PR merged.

Status
PASS
2026-02-15 — Build Route v2.4 — 2.16.6

Objective
Introduce machine-readable lane policy truth and enforce via merge-blocking CI gate (lane-policy-contract).

Changes
- Added docs/truth/lane_policy.json (authoritative lane taxonomy).
- Added scripts/lane_policy_contract.mjs (validator).
- Wired lane-policy-contract into CI and required.needs.
- Updated docs/proofs/manifest.json accordingly.

Proof
docs/proofs/2.16.6_lane_policy_truth_20260215_232809Z.log

DoD
PR opened → CI green → QA APPROVED → merged.

Status
CLOSED
2026-02-15 — Build Route v2.4 — 2.16.7 — Lane Enforcement Gate

Objective:
Implement and close lane-enforcement merge-blocking CI gate (2.16.7) with SOP-compliant proof.

Changes:
- Added lane-enforcement job to .github/workflows/ci.yml
- Wired job dependencies correctly (needs: [changes], no self-dependency)
- Finalized proof log: docs/proofs/2.16.7_lane_enforcement_20260215_200148.log
- Manifest updated automatically by proof_finalize.ps1
- Duplicates removed from required_checks.json via truth:sync

Proof:
- PROOF_FINALIZE_OK
- PROOF_MANIFEST_OK
- CI preflight passed (npm run pr:preflight)
- All merge-blocking gates green

DoD:
- PR merged to main
- CI green at merge
- Proof log and manifest verified
- QA APPROVE received

Status:
✅ Complete — SOP-compliant, merge-blocking gates satisfied, lane-enforcement operational.


## 2026-02-16 — Build Route v2.4 — 2.16.8 stop-the-line-xor

Objective  
- Establish merge-blocking XOR enforcement requiring exactly one acknowledgment (INCIDENT only) when stop-the-line condition is triggered.

Changes  
- Added CI job `stop-the-line-xor` (pull_request scope).  
- Wired job into `.github/workflows/ci.yml` `required.needs`.  
- Synced `docs/truth/required_checks.json`.  
- Added gate script `scripts/stop_the_line_xor_gate.mjs`.  
- Enforced PR-bound INCIDENT entry (PR #127).  

Proof  
- docs/proofs/2.16.8_stop_the_line_xor_20260216_150524Z.log  

DoD  
- Job id string-exact: `stop-the-line-xor`.  
- Runs on `pull_request`.  
- Activates only when stop-the-line is triggered.  
- PASS only if INCIDENT present AND WAIVER absent.  
- FAIL if neither present.  
- FAIL if both present.  
- FAIL if waiver file exists for the PR.  
- Included in `.github/workflows/ci.yml` `required.needs`.  
- Listed in `docs/truth/required_checks.json`.  
- Merge-blocking.  

Status  
- PASS


## 2026-02-16 — 2.16.9 — Waiver Policy Truth + Rate Limit Gate

**Objective**

* Encode mechanical anti–waiver-spam limits in truth and enforce via merge-blocking gate.

**Changes**

* Added `docs/truth/waiver_policy.json` (`window_days`, `max_waivers_in_window`).
* Implemented `scripts/waiver_rate_limit.mjs` (truth-driven window + threshold).
* Wired `waiver-rate-limit` job in `.github/workflows/ci.yml`.
* Added `CI / waiver-rate-limit` to `docs/truth/required_checks.json`.
* Generated + finalized proof log.

**Proof**

* `docs/proofs/2.16.9_waiver_rate_limit_20260216_201124Z.log`

**DoD**

* Truth file exists with required keys.
* Gate counts waivers in window.
* Gate fails if limit exceeded.
* Output includes window, counts, offending waivers.
* Merge-blocking wiring enforced.

**Status**

* PASS


## 2026-02-16 — Build Route v2.4 — 2.16.10 Robot-Owned File Guard

Objective  
- Enforce robot-owned artifact protection to prevent manual edits to machine-managed outputs.

Changes  
- Implemented `scripts/ci_robot_owned_guard.ps1`.
- Sourced robot-owned paths from `docs/truth/robot_owned_paths.json`.
- Allowed only canonical `<UTC>.log` for current objective + `docs/proofs/manifest.json`.
- Wired `robot-owned-guard` into `.github/workflows/ci.yml`.
- Synced `docs/truth/required_checks.json` via `truth:sync`.

Proof  
- docs/proofs/2.16.10_robot_owned_guard_20260216T210559Z.log
- Manifest updated via `proof:finalize`.
- CI green before merge.
- Post-merge `pr:preflight` passed on `main`.

DoD  
- Robot-owned allowlist defined via truth.
- Fail on unauthorized robot-owned edits.
- Explicit PASS/FAIL output with offending paths.
- Merge-blocking required check.
- Canonical proof log + manifest alignment.

Status  
- PASS

---

## 2026-02-16 — Clarified 2.16.11 Content Threshold

**Item:** 2.16.11 — Governance-Change Template Contract
**PR:** (fill in PR number after merge)

### Context

Item 2.16.11 required a “minimum non-whitespace content threshold per section (length floor)” but did not specify a numeric value. This left the gate underspecified and non-deterministic.

### Decision

Defined numeric minimum:

> **Minimum non-whitespace content per required section = 40 characters**

Applies individually to each required heading:

* `What changed`
* `Why safe`
* `Risk`
* `Rollback`

### Rationale

* Prevent empty or trivial boilerplate.
* Preserve structured governance traceability.
* Maintain low-to-moderate friction (rate-limiting governance mutation without turning it into essay-writing).
* Remove ambiguity so CI behavior matches authoritative spec.

### Impact

* Makes 2.16.11 fully specified and deterministic.
* No architectural change.
* No expansion of governance surface.
* Pure clarification of enforcement parameter.

---

## 2026-02-17 — Build Route v2.16.11 — Governance-Change Template Contract

Objective  
- Enforce structured governance-change justification with per-section length floor and merge-blocking CI gate.

Changes  
- Added CI job `governance-change-template-contract`.
- Implemented `scripts/ci_governance_change_template_contract.ps1`.
- Reused identical governance-touch matcher (2.15 logic via governance_touch_matcher).
- Enforced required headings (`What changed`, `Why safe`, `Risk`, `Rollback`).
- Enforced ≥40 non-whitespace characters per section.
- Updated required checks truth.
- Allowed 2.16.11 proof log in robot-owned-guard.

Proof  
- docs/proofs/2.16.11_governance_change_template_20260217T010033Z.log

DoD  
- Governance-touch PR requires `GOVERNANCE_CHANGE_PR*.md`.
- Headings string-exact enforced.
- Per-section ≥40 non-whitespace characters enforced.
- Merge-blocking gate active.
- Canonical proof log registered in manifest.

Status  
- PASS

git add docs/DEVLOG.md
git commit -m "DEVLOG: 2.16.11 Governance-Change Template Contract (closed)"

## 2026-02-17 — DEVLOG Correction — 2.16.5A–2.16.5G Status Clarification

The advisor review entry dated 2026-02-12 classified items 2.16.5A–2.16.5G as DORMANT.
This was superseded by subsequent implementation decisions. All seven items were implemented and merged:

- 2.16.5A — Foundation Boundary Contract — MERGED (PR #89)
- 2.16.5B — Repo Layout Separation — MERGED
- 2.16.5C — Foundation Invariants Suite — MERGED (BLOCKED mode, activates at 6.9)
- 2.16.5D — Lane Separation Enforcement — MERGED
- 2.16.5E — Foundation Versioning + Fork Protocol — MERGED
- 2.16.5F — Anti-Divergence Drift Detector — MERGED
- 2.16.5G — Product Scaffold Generator — MERGED

The DORMANT classification is no longer accurate. All items are active.
2.16.5C remains in BLOCKED mode pending foundation schema surface (unblocks at Build Route 6.9).

## 2026-02-17 — Section 2.16 Readiness Audit — Advisor Review

Purpose
Confirm enforcement completeness, identify silent bypass vectors, and validate readiness to proceed before moving to the next section. Section 2.16 is frozen. Audit scope: risk and integrity only. No redesign, no expansion, no reopening of closed items.

Advisors
Three independent advisors reviewed. Findings converged.

Question 1 — Can governance mutation occur without triggering declaration and enforcement?
ANSWER: No, with one residual vector.
- The enforcement stack is sound: governance-change-guard (2.15) + governance-change-template-contract (2.16.11) + truth-sync-enforced (2.16.4C) + ci-topology-audit (2.16.4B) + robot-owned-guard (2.16.10) collectively prevent silent governance mutation via normal PRs.
- Residual vector: the governance-touch path matcher did not cover supabase/foundation/** or docs/artifacts/FOUNDATION_BOUNDARY.md. A PR touching Foundation paths would not have triggered the declaration requirement.
- Resolution: gap closed via PR #138 (merged 2026-02-17). Both paths added to docs/truth/governance_change_guard.json.
- Secondary vector (accepted): GitHub Actions runner environment updates can shift gate behavior without code changes. Partially mitigated by 2.17.4 and 2.16.4C. Accepted external dependency risk.

Question 2 — Is proof discipline deterministic under failure?
ANSWER: Yes.
- Proofs are hash-tracked, append-only, and commit-bound.
- PREPROOF_HEAD repair protocol is specified and deterministic.
- POST_PROOF_NON_PROOF_CHANGE hard-fails.
- PROOF_SCRIPTS_HASH authority is declared in AUTOMATION.md and enforced with no globbing.
- Only remaining human-judgement element is identifying PREPROOF_HEAD during repair. Known, documented, accepted.

Question 3 — Is there any enforcement gap making the next section unsafe?
ANSWER: No blocking gap. Three items noted.
- Governance-touch matcher gap: CLOSED (PR #138).
- DEVLOG dormant/active contradiction for 2.16.5A-2.16.5G: CLOSED (this entry).
- 2.16.5C Foundation Invariants Suite: live infrastructure in BLOCKED mode. Exits zero when foundation schema surface is absent. Will auto-activate at Build Route item 6.9. No action required now. Track as live dependency.

Verdict
Section 2.16 is complete, green, and internally consistent.
Next section is 2.17 (Ported Files Stability Sweep).

## 2026-02-17 — Section 2.16 Audit Remediation

Actions taken following advisor review findings:

Fix 1 — Governance-touch matcher gap (PR #138)
- Added supabase/foundation/** and docs/artifacts/FOUNDATION_BOUNDARY.md to docs/truth/governance_change_guard.json.
- Created docs/governance/GOVERNANCE_CHANGE_PR138.md with required structured justification.
- npm run pr:preflight PASS before commit.
- PR #138 merged to main. Working tree clean post-merge.

Fix 2 — DEVLOG dormant/active contradiction
- Added clarifying entry to docs/DEVLOG.md confirming 2.16.5A-2.16.5G are active and merged.
- 2.16.5C noted as BLOCKED mode pending 6.9.
- No PR required. DEVLOG entry only.

Status
Both remediation items complete. Section 2.16 fully closed.

## 2026-02-17 — Build Route v2.4 — Added 13.2 Incident Resolution Deadline Enforcement

Objective
Add Build Route item 13.2 to close the gap identified in Section 2.16 readiness audit: INCIDENT entries required by 2.16.8 had no resolution deadline, allowing unresolved incidents to accumulate indefinitely while CI stayed green.

Changes
- Added item 13.2 to docs/artifacts/BUILD_ROUTE_V2.4.md under Section 13 (Recovery + Rollback).
- Item introduces incident_policy.json truth file, resolution marker convention, and merge-blocking gate incident-resolution-deadline.
- Waiver path explicitly forbidden for this gate.

Proof
- PR merged to main. Working tree clean post-merge.

DoD
- 13.2 exists in Build Route under Section 13.
- Hardening target explicitly references 2.16.8 as the legacy item being hardened.
- Implementation deferred to Section 13 execution.

Status
ADDED — implementation deferred until Section 13.

## 2026-02-18 — Build Route v2.4 — 2.17.1 Repository Normalization Contract

Objective
- Enforce deterministic LF + no-BOM normalization for governed paths with merge-blocking CI gate.

Changes
- Updated .gitattributes: stripped BOM, added LF rules for docs/**, generated/**, supabase/**
- Added scripts/ci_normalize_sweep.ps1
- Added npm run sweep:normalize to package.json
- Added CI job ci-normalize-sweep to .github/workflows/ci.yml, wired into required.needs
- Updated docs/truth/required_checks.json via npm run truth:sync
- Added 2.17.1 proof log exception to scripts/ci_robot_owned_guard.ps1

Proof
- docs/proofs/2.17.1_normalize_sweep_20260218T154346Z.log

DoD
- .gitattributes enforces LF + no-BOM for docs/**, generated/**, supabase/**
- npm run sweep:normalize runs renormalize on allowlisted paths only
- Running twice produces zero diff
- Any renormalization diff = failure
- Gate ci-normalize-sweep is merge-blocking

Status
- PASS

Understood.

This is a **governance-addition rationale entry**, not an implementation entry.

Insert this:

---

## 2026-02-18 — Build Route v2.4 — Added 2.17.1A (proof:finalize Invocation Hardening)

Objective
Record QA decision to introduce Build Route item 2.17.1A after recurring execution friction revealed a deterministic tooling weakness in `proof:finalize` argument passing.

Reason for Addition
During execution of 2.17.1, repeated failures occurred due to npm → PowerShell parameter forwarding ambiguity across Windows shells.
Although not a governance breach, the friction caused unnecessary Debugger Mode cycles and introduced risk of improper proof finalization patterns (manual quoting, inconsistent invocation forms).

QA determined this was:

* A systemic tooling weakness (not operator error),
* Recurring,
* Deterministic,
* And preventable through wrapper hardening.

2.17.1A was added to:

* Enforce positional argument canonicalization,
* Remove dependency on `-- -File` npm semantics,
* Preserve proof-binding invariants,
* Reduce governance execution risk.

Scope
Additive hardening only.
No policy change.
No gate weakening.
No modification to proof-commit-binding or manifest authority.

Status
Build Route updated.
Implementation tracked under item 2.17.1A.


2026-02-18 — Build Route v2.4 — 2.17.1A

Objective
Harden proof:finalize invocation to deterministic cross-shell positional arg form without weakening proof discipline.

Changes
Added scripts/proof_finalize_wrapper.mjs (Node wrapper enforcing positional arg + validation).
Updated package.json proof:finalize to call wrapper.
Updated docs/artifacts/SOP_WORKFLOW.md canonical finalize command to positional form.
Updated scripts/ci_robot_owned_guard.ps1 to allow 2.17.1A proof log pattern.

Proof
docs/proofs/2.17.1A_proof_finalize_arg_hardening_20260218T175242Z.log

DoD
Positional npm run proof:finalize docs/proofs/<ITEM>_<UTC>.log works on Windows without -- -File.
Legacy -File still supported.
Hard-fail on invalid/missing/outside path.
Finalize only mutates proof log + manifest.
proof-manifest + proof-commit-binding green.

Status
PASS

## 2026-02-18 — Build Route v2.4 — 2.17.2 Encoding & Hidden Character Audit

Objective
- Validate and enforce no BOM, no zero-width, and no disallowed control characters in all guarded paths.

Changes
- Extended scripts/fix_encoding.ps1 to strip zero-width, ANSI escapes, NUL bytes; enforce LF-only.
- Added scripts/ci_encoding_audit.ps1 as merge-blocking gate.
- Ran fix:encoding to sanitize repo.
- Updated scripts/ci_robot_owned_guard.ps1 to allow repaired legacy proof logs and canonical 2.17.2 log.
- Captured canonical proof log docs/proofs/2.17.2_encoding_audit_20260218T214411Z.log.

Proof
- PROOF_HEAD set to 2.17.2 tail commit.
- Manifest updated for all repaired logs.
- All CI gates green, robot-owned-guard PASS.

DoD
- No BOM in guarded paths.
- No zero-width characters.
- Only allowed control chars (TAB/LF/CR).
- ci-encoding-audit gate fails only on forbidden classes.
- Canonical proof log finalized via proof:finalize.
- Robot-owned guard green, no manual edits to proof artifacts.

Status
- PASS

## 2026-02-19 — Build Route v2.4 — 2.17.3 Absolute Path / Machine Leak Audit

Objective  
- Enforce repo-relative path discipline for high-risk outputs (`generated/**`, `docs/proofs/**`) and block absolute machine root leaks.

Changes  
- Added `scripts/ci_path_leak_audit.ps1` (blocking scope + alert-only docs scope).
- Wired new CI job `ci-path-leak-audit` in `.github/workflows/ci.yml`.
- Added required check entry in `docs/truth/required_checks.json`.
- Expanded `ci_robot_owned_guard.ps1` allowlist per SOP §3.2 repair.
- Redacted historical proof logs to remove absolute machine roots.
- Re-finalized affected proof logs via `npm run proof:finalize`.
- Updated `docs/proofs/manifest.json` via finalize only.

Proof  
- docs/proofs/2.17.3_path_leak_audit_20260219T004738Z.log

DoD  
- Blocking scope: `generated/**`, `docs/proofs/**` (incl. manifest.json).
- No `C:\`, `C:/`, `/Users/`, `/home/runner/` in blocking scope.
- `docs/**` outside `docs/proofs/**` = alert-only.
- Gate `ci_path_leak_audit` blocks only on blocking scope.

Status  
- PASS


## 2026-02-19 — Build Route v2.4 — 2.17.4 Parser Contract Resilience Check

Objective  
- Establish fixture-based validator robustness and deterministic output verification.

Changes  
- Added adversarial fixture pack (CRLF, mixed bullets, trailing spaces, blank lines).
- Implemented scripts/ci_validator.ps1 to normalize validator output and hash per fixture.
- Wired lane-only CI job ci-validator in workflow (non merge-blocking).

Proof  
- docs/proofs/2.17.4_parser_fixture_check_20260219T012954Z.log

DoD  
- Fixture pack includes required adversarial cases.
- Determinism comparator hashes normalized validator output per fixture.
- Gate fails on any validator error class.
- Proof finalized via proof:finalize.
- Lane-only CI wiring (not in required checks).

Status  
- PASS

2026-02-18 — Build Route v2.4 — Section 3 Pre-Implementation Risk Hardening

Objective
Formalize execution constraints before modifying enforcement tooling (Section 3), addressing advisor-identified self-referential validation risk.

Changes
- Confirmed SECURITY DEFINER search_path enforcement is mechanically enforced by ci_definer_safety_audit (merge-blocking).
- Verified clean main (git status clean, pr:preflight PASS).
- Inspected docs/proofs/manifest.json — no stale entries, no WORKING logs, no duplicates.
- Added “3.0 — Section 3 Execution Constraints (LOCKED)” to Build Route v2.4.
- Added Triple Registration Rule for any new truth artifact introduced in Section 3.

Logic
Section 3 modifies enforcement tools (handoff, ship, green:*, proof-commit-binding).  
Risk class shifts from governance wiring to self-referential validation.  
Constraints added to:
- Prevent simultaneous modification of verification paths (ship vs green:*).
- Isolate proof-commit-binding changes from other automation changes.
- Enforce one enforcement surface per PR for attribution and rollback clarity.
- Require deterministic green:once + green:twice before proof generation.
- Prevent partially governed truth artifacts via mandatory triple registration.

Proof
- pr:preflight PASS on main.
- ci_definer_safety_audit inspection confirming search_path enforcement.
- Governance PR updating Build Route with Section 3 constraints.
- Advisor review returned PASS.

DoD
- Section 3 constraints committed in-repo.
- Triple registration rule included.
- Clean main verified per SOP §13.
- Advisor review closed with PASS.

Status
PASS


2026-02-18 — Build Route v2.4 — Section 3 Item Reordering and Scope Clarification

Objective
Incorporate QA-reviewed reordering and structural clarification of Section 3 (Automation Build) to minimize circular validation risk and enforce explicit dependency sequencing.

Changes
- Adopted authoritative execution order for Section 3 items (3.1 → 3.7).
- Repositioned Ship guard to 3.2 (likely proof-only checkpoint before broader automation changes).
- Clarified relationship between 3.3 (handoff-commit-safety implementation) and 11.2 (release re-verification of same gate).
- Explicitly separated 3.6 robot-owned-publish-guard from 2.16.10 robot-owned-guard (edit prevention vs generation prevention).
- Added pre-implementation checks to each item to determine proof-only vs implementation scope.
- Elevated 3.7 QA verify as meta-gate built last to avoid circular dependency.
- Required explicit PR-scope mapping mechanism definition before implementing 3.7.
- Documented authoritative execution order table and risk summary table in Section 3.

Logic
Section 3 modifies enforcement tooling and therefore introduces self-referential validation risk.
Reordering ensures:
- Contract definition (3.1) precedes enforcement.
- Existing guards (3.2–3.4) are validated before introducing new truth artifacts.
- Triple-registration risk (3.5) is handled before generator enforcement (3.6).
- Meta-gate (3.7) is implemented last to validate prior proofs rather than itself.

This sequencing reduces circular dependency exposure and ensures stable validation surfaces remain during each PR.

Proof
- Governance PR updating Section 3 ordering and structure.
- QA review confirming revised sequence minimizes circular validation risk.

DoD
- Section 3 ordering committed in-repo.
- Pre-implementation checks explicitly defined.
- Gate relationships clarified (3.3 ↔ 11.2, 2.16.10 ↔ 3.6).
- QA approved revised sequence.

Status
PASS



## 2026-02-19 — Build Route v2.4 — Section 3 Deferred (DB Dependency)

Objective
Defer Section 3 (Automation Build) until Section 4 establishes a functional DB.

Changes
- No files modified. Deferral recorded only.

Proof
- N/A (deferral entry; no proof artifact required)

DoD
- Section 3 constraints documented in Build Route (DONE — merged).
- Deferral reason recorded here per SOP §14.

Reason
- ship hangs at encoding preflight without DB.
- ship and green:twice previously pulled unwanted Supabase data (cleanup required).
- green:once, green:twice non-functional without DB.
- Section 3.0 constraint #2 (green:once + green:twice before proof) cannot be satisfied.
- 3.1 DoD requires demonstrating command behaviors that are unsafe to execute in current state.

Decision
Section 3 deferred. Section 4 (Fresh Supabase Project Baseline) proceeds next.
Section 3 resumes after 4.1 + 4.2a (Command Smoke DB lane) confirms commands are safe.

Status
BLOCKED — resumed after Section 4

---

## 2026-02-19 — Build Route v2.4 — 4.1 Cloud Baseline

Objective
Establish a fresh Supabase cloud project with no legacy imports as the clean DB foundation for all subsequent sections.

Changes
- Created new Supabase project WHOLESALEHUB (ref: upnelewdvbicxvfgzojg) on supabase.com.
- Linked local repo via npx supabase link --project-ref upnelewdvbicxvfgzojg.
- No migrations pushed to cloud (Section 6 scope).
- Allowlisted docs/proofs/4.1_cloud_baseline_20260219_144802.md in scripts/ci_robot_owned_guard.ps1.

Proof
- docs/proofs/4.1_cloud_baseline_20260219_144802.md

DoD
- New project created on supabase.com — project ref captured: upnelewdvbicxvfgzojg
- Proof asserts no legacy schema or data import occurred
- REBUILD MODE: no legacy migrations ported, no restore from backup

Status
PASS


## 2026-02-19 — Build Route v2.4 — 4.2 Supabase Toolchain Contract

Objective
Pin Supabase CLI and psql versions in toolchain truth and enforce via merge-blocking CI gate.

Changes
- Added supabase_cli and psql entries to docs/truth/toolchain.json.
- Added scripts/ci_toolchain_supabase.ps1 gate script.
- Added toolchain:contract:supabase npm script to package.json.
- Added toolchain-contract-supabase CI job to .github/workflows/ci.yml.
- Added toolchain-contract-supabase to required job needs list.
- Updated docs/truth/required_checks.json via npm run truth:sync.
- Allowlisted 4.2 proof log in scripts/ci_robot_owned_guard.ps1.

Proof
- docs/proofs/4.2_toolchain_versions_supabase_<UTC>.log

DoD
- CI hard-fails on Supabase CLI version mismatch.
- CI hard-fails on psql version mismatch (CI-only; graceful skip locally).
- Gate toolchain-contract-supabase is merge-blocking.

Status
PASS


2026-02-19 — Build Route v2.4 — QA Ruling: Keep handoff merge-blocking; unblock via minimal baseline; add 6.1A hardening

Objective
Record QA decision to keep `handoff` as a merge-blocking truth publisher, unblock current REBUILD-mode execution with the smallest legitimate baseline schema change, resume Section 3 after Section 4.2 baseline, and define a later hardening step (6.1A) to prevent regex-only preconditions from being trivially satisfiable.

Reasoning
- `handoff` generates authoritative truth artifacts (`generated/schema.sql`, `generated/contracts.snapshot.json`, `docs/handoff_latest.txt`). It must remain merge-blocking in DB/runtime lanes because publishing truth from an empty/wrong DB normalizes invalid state.
- Current failure (`must_contain` missing `public.tenants`) is a legitimate tripwire firing: the schema dump lacks the required object because baseline migrations do not yet exist in REBUILD MODE. This is not a script bug and does not justify weakening gates or skipping checks.
- Immediate unblock strategy is not a bypass: introduce the minimum forward-only baseline migration required to make the invariant true (create `public.tenants` so the dumped schema reflects real minimum structure and `handoff` can proceed).
- With DB baseline established via Section 4.2 (enough to run DB-coupled commands), the correct sequencing is to return to Section 3 to lock down automation/publisher behavior before expanding further DB work.
- Future hardening is required because the current `must_contain` tripwire is regex-based against schema text and can be satisfied by a minimal stub indefinitely. Add Build Route item 6.1A immediately after 6.1 (baseline migrations) to upgrade `handoff` preconditions to DB-state validation (table/column/PK presence) before truth generation.

Action
- Keep `handoff` merge-blocking; do not conditionalize/disable `must_contain`.
- Unblock `handoff` now via minimal baseline migration (create `public.tenants`).
- After Section 4.2 baseline, resume Section 3 execution.
- Add 6.1A after 6.1 to harden `handoff` with DB-state preconditions once baseline migrations exist.

Status
Recorded — merge-blocking stance preserved; minimal-baseline unblock accepted; sequencing set to return to Section 3; 6.1A defined and correctly placed.



## 2026-02-19 — Build Route v2.4 — 4.2a Command Smoke (DB Lane)

Objective
Prove DB-coupled commands run end-to-end without crash on a machine with Supabase running.

Changes
- Added greenfield baseline migrations (REBUILD MODE, no legacy import):
  - supabase/migrations/20260219000000_baseline_tenants.sql
  - supabase/migrations/20260219000001_baseline_tenant_memberships.sql
  - supabase/migrations/20260219000002_baseline_user_profiles.sql
  - supabase/migrations/20260219000003_baseline_deals.sql
- Fixed scripts/contracts_lint.ps1 patterns to match current CONTRACTS.md format (Debugger Mode).
- Added handoff artifact exceptions to scripts/ci_robot_owned_guard.ps1.
- handoff wrote generated/schema.sql, generated/contracts.snapshot.json, docs/handoff_latest.txt.
- Proof log sanitized after secret exposure in prior attempt (branch reset per SOP repair protocol).

Proof
- docs/proofs/4.2a_command_smoke_db_20260219T180422Z.log

DoD
- green:once -- PASS
- green:twice -- PASS
- handoff -- PASS (artifacts written, CONTRACTS LINT OK, MUST_CONTAIN OK)
- ship -- PASS (verify-only, zero diffs, no writes/commits/push)

Status
PASS

## 2026-02-19 — Build Route v2.4 — 3.1 Automation Contract Acceptance

Objective
Create gate script that mechanically verifies command separation per AUTOMATION.md Checklist 3.1.

Changes
- Added scripts/ci_automation_contract.ps1 (11 behavioral assertions).
- Added automation:contract npm script to package.json.
- Added automation-contract CI job to .github/workflows/ci.yml.
- Added automation-contract to required job needs list (merge-blocking).
- Updated docs/truth/required_checks.json via npm run truth:sync.
- Allowlisted 3.1 proof log in scripts/ci_robot_owned_guard.ps1.

Proof
- docs/proofs/3.1_automation_contract_<UTC>.log

DoD
- Gate script asserts behaviors programmatically (not narrative).
- Gate output demonstrates each command mode: handoff / handoff:commit / ship / green:*.
- Behaviors match Checklist 3.1 exactly.
- Gate is merge-blocking.

Status
PASS

## 2026-02-19 — Build Route v2.4 — 3.2 Ship Guard

Objective
Establish ship-guard as a merge-blocking CI gate proving ship is always verify-only.

Changes
- Renamed scripts/ship_guard.ps1 to scripts/ci_ship_guard.ps1 (pwsh-fixed for Ubuntu CI).
- Created scripts/ci_ship_guard_contract.ps1 -- structural assertion gate (8 assertions, Option A per QA ruling).
- Added ship-guard CI job to .github/workflows/ci.yml calling ci_ship_guard_contract.ps1.
- Added ship-guard to required.needs (merge-blocking).
- Updated docs/truth/required_checks.json via npm run truth:sync.
- Updated package.json to reference ci_ship_guard.ps1.
- Allowlisted 3.2 proof log in scripts/ci_robot_owned_guard.ps1.

Proof
- docs/proofs/3.2_ship_guard_20260219T231834Z.log

DoD
- ship fails on dirty tree -- ci_ship_guard.ps1 throws on dirty working tree.
- ship fails on disallowed branch -- ci_ship_guard.ps1 throws if branch != main.
- ship fails if it produces diffs -- artifact diff check in ci_ship_guard.ps1.
- ship-guard is merge-blocking CI gate.
- QA Option A complied with -- no bypass flags in enforcement script.
- npm run ship on main post-merge: GATES PASSED, zero diffs, EXIT 0.

Status
PASS

## 2026-02-20 — Build Route v2.4 — 3.3 handoff:commit Push Semantics

Objective
Establish unambiguous publishing semantics for handoff:commit -- refuses detached HEAD, refuses main, pushes current branch only.

Changes
- Hardened scripts/handoff_commit.ps1: added detached HEAD check, fixed powershell -> pwsh.
- Created scripts/ci_handoff_commit_contract.ps1 -- structural assertion gate (7 assertions).
- Added handoff-commit-safety CI job to .github/workflows/ci.yml.
- Added handoff-commit-safety to required.needs (merge-blocking).
- Updated docs/truth/required_checks.json via npm run truth:sync.
- Allowlisted 3.3 proof log in scripts/ci_robot_owned_guard.ps1.

Proof
- docs/proofs/3.3_handoff_commit_push_20260220T003148Z.log

DoD
- handoff:commit refuses detached HEAD.
- handoff:commit refuses pushing to main (auto-creates PR branch).
- handoff:commit pushes current branch only and prints remote ref pushed.
- Gate handoff-commit-safety is merge-blocking.

Status
PASS

## 2026-02-20 — Build Route v2.4 — SOP_WORKFLOW §13 + §16 Clarification

Objective
Clarify post-merge verification sequence and handoff/ship execution timing in SOP_WORKFLOW.md.

Changes
- §13 renamed to "Post-Merge Verification (LOCKED)"; added npm run ship as mandatory post-merge step; added Debugger Mode trigger if ship fails on main.
- §16 added "When to run handoff" and "When to run ship" subsections with summary table (command / when / branch / writes files).

Proof
- Governance artifact update. No gate or proof artifact required.

DoD
- §13 includes ship in post-merge sequence.
- §16 clarifies handoff = PR branch before merge, ship = main after merge.
- No policy change. No gate weakening. Clarification only.

Status
PASS

## 2026-02-20 — Build Route v2.4 — 3.4 Docs Publish Contract

Objective
Establish docs-push-contract as a merge-blocking CI gate proving docs:push cannot mutate robot-owned outputs.

Changes
- Hardened scripts/docs_push.ps1: added detached HEAD, main refusal, clean tree, and robot-owned path checks.
- Created scripts/ci_docs_push_contract.ps1 -- structural assertion gate (9 assertions).
- Added docs-push-contract CI job to .github/workflows/ci.yml.
- Added docs-push-contract to required.needs (merge-blocking).
- Updated docs/truth/required_checks.json via npm run truth:sync.
- Allowlisted 3.4 proof log in scripts/ci_robot_owned_guard.ps1.

Proof
- docs/proofs/3.4_docs_push_20260220T135829Z.log

DoD
- docs:push refuses detached HEAD.
- docs:push refuses pushing to main.
- docs:push requires clean tree.
- docs:push refuses if diff touches robot-owned paths.
- Gate docs-push-contract is merge-blocking.

Status
PASS

## 2026-02-20 — Build Route v2.4 — 3.5 QA Requirements Truth

Objective
Establish qa-requirements-contract as a merge-blocking CI gate proving qa_requirements.json validates against schema and cannot be weakened silently.

Changes
- Created scripts/ci_qa_requirements_contract.ps1 -- schema validation + version-bump enforcement gate.
- Added qa-requirements-contract CI job to .github/workflows/ci.yml.
- Added qa-requirements-contract to required.needs (merge-blocking).
- Updated docs/truth/required_checks.json via npm run truth:sync.
- Registered 3.5 proof log in scripts/ci_robot_owned_guard.ps1 (§3.0.4a).
- §3.0.4b already satisfied: qa_requirements.json + schema in truth_bootstrap_check.mjs.
- §3.0.4c exempt: hand-authored file, not machine-derived.

Proof
- docs/proofs/3.5_qa_requirements_20260220T144336Z.log

DoD
- qa_requirements.json validates against qa_requirements.schema.json.
- Version bump enforced only when qa_requirements.json is in PR diff.
- Gate qa-requirements-contract is merge-blocking.

Status
PASS

## 2026-02-20 — Build Route v2.4 — 3.6 Robot-Owned Generator Enforcement

Objective
Establish robot-owned-publish-guard as a merge-blocking CI gate proving generator outputs cannot be produced/modified outside handoff:commit.

Changes
- Created scripts/ci_robot_owned_publish_guard.ps1 -- independent gate distinct from robot-owned-guard (2.16.10).
- Added robot-owned-publish-guard CI job to .github/workflows/ci.yml (fetch-depth: 0).
- Added robot-owned-publish-guard to required.needs (merge-blocking).
- Updated docs/truth/required_checks.json via npm run truth:sync.
- Allowlisted 3.6 proof log in scripts/ci_robot_owned_guard.ps1.

Proof
- docs/proofs/3.6_robot_owned_publish_guard_20260220T151622Z.log

DoD
- CI fails if generated/** or docs/handoff_latest.txt modified outside handoff:commit.
- Gate is distinct from robot-owned-guard (2.16.10) -- different enforcement surface.
- Gate is merge-blocking.

Status
PASS

---

## 2026-02-20 — Build Route v2.4 — 3.7 QA Verify (Meta-Gate)

**Objective**

* Establish deterministic PR-scope completeness gate enforcing required proof presence per claimed Build Route item.

**Changes**

* Added `scripts/qa_verify.mjs` completeness gate.
* Added `docs/truth/qa_scope_map.json` (item → required proof patterns).
* Added `docs/truth/qa_claim.json` (single claimed item per PR).
* Wired `qa:verify` script in `package.json`.
* Added CI job `qa-verify` and registered in `required_checks.json`.
* Registered truth artifacts in robot-owned guard + truth-bootstrap.
* Documented scope mechanism in `docs/artifacts/AUTOMATION.md`.

**Proof**

* `docs/proofs/3.7_qa_verify_<UTC>.log`

**DoD**

* `npm run qa:verify` emits STATUS PASS/FAIL.
* Validates required proofs for claimed item exist in manifest.
* No branch-name / label / inference logic.
* No hash duplication of proof-manifest.
* Scope mechanism documented in AUTOMATION.md.

**Status**

* PASS


Copy/paste block below.

---

## 2026-02-20 — Build Route v2.4 — Governance Change Guard Merge-Blocking Hardening (PER QA INSTRUCTION)

Objective

* Enforce governance-change-guard as true merge-blocking control.

Changes

* Added `governance-change-guard` to `required.needs` (string-exact).
* Synced `docs/truth/required_checks.json`.
* Verified `docs/truth/governance_change_guard.json` path scope.
* Executed regression: fail without `GOVERNANCE_CHANGE_PR<NNN>.md`, pass with it.
* Removed regression artifacts after validation.
* Locked governance wiring requirements in SOP.

Proof

* Red CI on missing governance file.
* Green CI after adding `GOVERNANCE_CHANGE_PR008.md`.
* Ship passed on main.

DoD

* Guard blocks merges on governance path mutation.
* Required job includes guard string-exactly.
* Regression validated.

Status

* PASS

## 2026-02-20 — Build Route v2.4 — Added 3.8 Handoff Idempotency Enforcement

Objective
Add Build Route item 3.8 to close handoff convergence gap discovered during advisor meeting prep.

Reason for Addition
Running npm run handoff on clean main with committed truth artifacts always dirties the tree. This creates an impossible loop: ship verifies zero diffs, but handoff always produces diffs even when nothing changed. The generator is not idempotent — it either produces nondeterministic output or self-references its own writes (handoff_latest.txt records git status after writing files).

This means:
- ship verification is meaningless (handoff always dirties tree)
- handoff:commit is required even when nothing changed
- Post-merge clean tree invariant is fragile

3.8 was added to:
- Make handoff idempotent (second run = zero diffs)
- Fix nondeterministic generators (schema.sql, contracts.snapshot.json, handoff_latest.txt)
- Enable ship to meaningfully verify truth artifact correctness

Scope
Section 3 item. Section 3.0 constraints apply.
One enforcement surface per PR.
No gate weakening.

Status
ADDED — implementation immediate (pre-advisor meeting).

2026-02-21 — Build Route v2.4 — 3.8 Handoff Idempotency Enforcement

Objective
Assert handoff is idempotent: two consecutive runs (no commits between) produce identical output.

Changes
- scripts/ci_handoff_idempotency.ps1 — new gate (CI-stub; full local run + working tree restore)
- scripts/handoff.ps1 — filter robot-owned files from git status capture
- scripts/ci_robot_owned_guard.ps1 — allowlisted 3.8 proof log pattern
- .github/workflows/ci.yml — handoff-idempotency job added, wired into required:
- docs/truth/required_checks.json — CI / handoff-idempotency added
- generated/contracts.snapshot.json — corrected stale artifact via handoff:commit
- docs/governance/GOVERNANCE_CHANGE_PR011.md — governance file

Proof
docs/proofs/3.8_handoff_idempotency_20260221T025034Z.log

DoD
1. Two consecutive handoff runs produce zero diffs ✓
2. Gate asserts idempotency locally ✓
3. CI stub passes (db-heavy pattern) ✓
4. handoff:commit published truth artifacts per SOP §16 ✓
5. ship passed on main post-merge ✓

Status: COMPLETE

2026-02-21 — Build Route v2.4 — Section 3 Closed

Objective
Verify all Section 3 items complete and main is stable per SOP §17.

Changes
- No implementation changes. Verification only.

Verification evidence
- git status: clean
- pr:preflight: PASS
- ship: PASS
- handoff idempotency: PASS (schema.sql + contracts.snapshot.json zero diffs)
- green:twice: PASS
- handoff_latest.txt HEAD drift: expected by design (one commit behind after handoff:commit)

Status: COMPLETE


## 2026-02-21 — Build Route v2.4 — Advisor Review: Section 3 Seal + Forward Risk (Sections 4–7)

Objective
- Record findings from external adversarial advisor review of Section 3
  seal status and forward risk across Sections 4–7, per SOP §14
  (advisor review findings require DEVLOG entry).

Changes
- No implementation changes. Findings only.

Proof
- Advisor review transcript (session record).

DoD
- Section 3 seal status assessed.
- Forward risk for Sections 4–7 documented.
- All actionable findings converted to Build Route items or hardening
  DoD additions in the same session (see companion entry below).

Findings summary

Section 3 — Seal Status
- Governance and automation layer: SEALED.
- Security layer: claimed but unproven. Privilege firewall and
  SECURITY DEFINER assertions are text-match detections on
  generated/schema.sql, not live-DB proofs. Security seal deferred
  to Section 6 pgTAP tests. DB-heavy stubs must be explicitly catalogued
  before Section 4 entry — addressed by 3.9.1.
- qa:verify deliberate-failure regression not documented in 3.7 DEVLOG.
  Addressed by 3.9.3.
- Governance-change-guard reuse-of-prior-governance-file bypass: low
  risk for solo team, documented.
- AUTOMATION.md §2 declares database-tests.yml as required; file does
  not exist. Live compliance gap. Catalogued in 3.9.1 deferred proof
  registry.

Section 4 — Integrity Gate
- anon role default privilege gap: no gate proves anon has zero access.
  New item: 4.4.
- Tenancy resolution deviation detection absent. New item: 4.5.
- PostgREST and Auth version not pinned in inventory. Hardening: 4.3.
- JWT context drift in background/trigger contexts identified as risk.
  Addressed by 6.3 hardening (background_context_review.json).
- write_path_registry gap: no proof that all write paths check
  row_version. Addressed by 6.6 hardening.

Section 5 — Reliability Gate
- Partial migration exposure window: table created before RLS enabled.
  New item: 5.1.
- Manifest corruption has no documented repair path beyond SOP §4.2.
  Existing SOP §4.2 Repair Protocol is the authoritative path; no
  separate recovery script warranted.
- Rollback migration tested on empty DB only — risk noted for future
  Section 8 work.

Section 6 — Product Gate
- UI error bucketing: PGRST301 vs 42501 indistinguishable at HTTP
  layer. Risk documented for Section 10 (WeWeb integration).
- Empty-result tenant isolation false-pass: tests must use populated
  data. Addressed by 6.3 hardening.
- View and FK embedding coverage absent from isolation suite.
  Addressed by 6.3 hardening.
- Unregistered table access (table added without selector entry).
  New item: 6.3A.
- Share token not proven tenant-scoped at planner level. Addressed
  by 6.7 hardening.
- calc_version change protocol absent. New item: 7.6.

Section 7 — Launch Gate
- Service role key in CI log risk via PowerShell Write-Error paths.
  Addressed by 3.9.5 (proof secret scan).
- Studio direct mutation has no drift detection. New item: 7.7.
- PostgREST cloud version drift undetected. Addressed by 4.3 hardening.
- anon role not explicitly in privilege_truth.json. Addressed by
  7.2 hardening.
- pg_proc.prosrc used incorrectly for search_path check — correct
  field is pg_proc.proconfig. Addressed by 6.2 hardening.

Status
- RECORDED (findings only — no gate, no proof artifact required per
  SOP §14 advisor review entry type)

---

## 2026-02-21 — Build Route v2.4 — Build Route Additions: Section 3.9 + Sections 4–7 Hardenings

Objective
- Record all Build Route additions and hardenings produced from the
  advisor review session. Per SOP §14, Build Route additions require
  a DEVLOG entry.

Changes

Section 3.9 — Pre-Section-4 Bridge Hardening (new section)
- Added Section 3.9 as a formal addendum to Section 3, comprising
  sub-items 3.9.0 through 3.9.6.
- 3.9.0: Bridge execution constraints (LOCKED).
- 3.9.1: Deferred proof registry — catalogs all DB-heavy stub gates
  and AUTOMATION.md §2 compliance gap. Gate: deferred-proof-registry.
- 3.9.2: Governance path coverage audit — closes guard coverage gap,
  adds governance_surface_definition.json, resolves package.json scope
  ambiguity. Gate: governance-path-coverage.
- 3.9.3: QA scope map coverage enforcement — closes qa:verify
  trivial-pass blind spot, adds deliberate-failure regression
  requirement. Gate: qa-scope-coverage.
- 3.9.4: Job graph ordering verification — proves lane-enforcement is
  prerequisite of docs-only-ci-skip. Gate: job-graph-ordering.
- 3.9.5: Proof secret scan — hardens proof:finalize to reject secrets
  before manifest entry. Must be on main before first Section 4 proof.
- 3.9.6: Bridge close verification — formal §17-style close with
  DEVLOG entry requirement before Section 4 entry.
- Governance position clarified: Section 3 is not reopened. 3.9 is
  an addendum. Second DEVLOG entry ("Section 3.9 Bridge Closed")
  required before Section 4 opens.

Section 4 — Fresh Supabase Project Baseline
- 4.3 hardened: PostgREST and Auth version pinning added as lane-only
  cloud-version-pin gate. toolchain-contract-supabase not extended.
- 4.4 added: anon role default privilege audit.
  Gate: anon-privilege-audit (merge-blocking, DB lane).
- 4.5 added: Tenancy resolution contract enforcement — forbidden
  pattern detection only, no re-adjudication of CONTRACTS.md §3.
  Gate: rls-strategy-consistent (merge-blocking, migration lane).

Section 5 — Governance Gates
- 5.0 hardened: new gates registered per-item in their own PRs,
  not batched. Governance-change-guard trigger documented per item.
- 5.1 added: Migration RLS co-location lint — CREATE TABLE must be
  accompanied by ENABLE ROW LEVEL SECURITY + REVOKE ALL in same file.
  Includes baseline migration pre-check requirement.
  Gate: migration-rls-colocation (merge-blocking).

Section 6 — Greenfield Schema Build
- 6.2 hardened: pg_proc.proconfig (not prosrc) used for search_path
  catalog check. Helper function schema-qualification enumerated.
- 6.3 hardened: populated-data requirement for negative tests,
  view-based access tests, FK embedding HTTP tests, and
  background_context_review.json with catalog cross-check gate added.
- 6.3A added: Unregistered table access gate.
  Gate: unregistered-table-access (merge-blocking).
- 6.4 hardened: specific forbidden policy patterns enumerated.
  Policy expression enumeration added to proof artifact requirement.
- 6.6 hardened: write_path_registry.json (machine-derived, full Triple
  Registration) and concurrent row_version update test added.
- 6.7 hardened: tenant-scoped token lookup WHERE clause requirement,
  EXPLAIN query plan evidence requirement added.

Section 7 — Schema + Privilege Truth
- 7.2 hardened: anon role explicit in privilege_truth.json.
  Contract-based GRANT allowlist lint replaces documentation-comment
  approach.
- 7.6 added: calc_version change protocol.
  Gate: calc-version-registry (merge-blocking).
- 7.7 added: Supabase Studio direct-mutation guard.
  Operator-run only. No CI job. Policy-governed.

Proof
- Advisor review transcript (session record).
- BUILD_ROUTE_V2_4_SECTION_3.9.md (revised Section 3.9 document).
- BUILD_ROUTE_V2_4_SECTIONS_4_7_ADDITIONS.md (revised Sections 4–7
  additions in Build Route format).

DoD
- All advisor findings converted to Build Route items or hardening
  additions.
- Section 3.9 document revised: numbering, governance position,
  execution constraints, and all six sub-item corrections applied.
- Sections 4–7 additions formatted in Build Route standard and
  corrections from advisor review applied.
- No implementation changes in this entry. Implementation follows
  per-item PRs beginning with 3.9.1.

Status
- RECORDED

2026-02-21 — Build Route v2.4 — 3.9.1 Deferred Proof Registry

Objective
Establish a machine-readable registry cataloging every CI gate currently passing as a DB-heavy stub, so stub-passing gates cannot be silently interpreted as security evidence.

Changes
- docs/truth/deferred_proofs.json — new registry (db-heavy, database-tests.yml)
- docs/truth/deferred_proofs.schema.json — schema validating registry structure
- scripts/ci_deferred_proof_registry.ps1 — new gate
- .github/workflows/ci.yml — deferred-proof-registry job added, wired into required:
- docs/truth/required_checks.json — CI / deferred-proof-registry added
- docs/truth/qa_claim.json — updated to 3.9.1
- docs/truth/qa_scope_map.json — added 3.9.1 entry
- docs/governance/GOVERNANCE_CHANGE_PR016.md — governance file
- scripts/ci_robot_owned_guard.ps1 — allowlisted 3.9.1 proof log

Proof
docs/proofs/3.9.1_deferred_proof_registry_20260221T213946Z.log

DoD
1. deferred_proofs.json exists with one entry per db-heavy stub gate
2. deferred_proofs.schema.json validates registry structure
3. Gate fails if stub gate has no registry entry
4. Gate fails if converted gate still has registry entry
5. AUTOMATION.md gap (database-tests.yml) catalogued with conversion_trigger 6.0/8.0
6. CI green, QA approved, merged

Status: COMPLETE

2026-02-21 — Build Route v2.4 — 3.9.2 Governance Path Coverage Audit

Objective
Mechanically assert that governance_change_guard.json path matchers cover every governance-surface file in the repo — closing the bypass class where new governance-surface paths silently escape the guard.

Changes
- docs/truth/governance_surface_definition.json — new versioned governance surface definition (12 patterns, 3 exclusions)
- docs/truth/governance_change_guard.json — added BUILD_ROUTE_V2.4.md, RELEASES.md, governance_surface_definition.json
- scripts/ci_governance_path_coverage.ps1 — new gate
- .github/workflows/ci.yml — governance-path-coverage job added, wired into required:
- docs/truth/required_checks.json — CI / governance-path-coverage added
- docs/truth/qa_claim.json — updated to 3.9.2
- docs/truth/qa_scope_map.json — added 3.9.2 entry
- scripts/ci_robot_owned_guard.ps1 — allowlisted 3.9.2 proof log
- docs/governance/GOVERNANCE_CHANGE_PR018.md — governance file

Decisions
- package.json: Option B — excluded from governance scope
- docs/governance/**: excluded — circular by design
- BUILD_ROUTE_V2.4.md + RELEASES.md: added to guard

Proof
docs/proofs/3.9.2_governance_path_coverage_20260221T230558Z.log

DoD
1. governance_surface_definition.json exists with versioned path patterns
2. Gate fails if any surface file uncovered by guard
3. governance_change_guard.json updated to cover all gaps
4. governance_surface_definition.json added to guard scope (self-registering)
5. CI green, QA approved, merged

Status: COMPLETE

2026-02-21 — Build Route v2.4 — 3.9.3 QA Scope Map Coverage Enforcement

Objective
Assert that qa_scope_map.json has an entry for every completed Build Route item, closing the blind spot where an unmapped item trivially passes qa:verify.

Changes
- docs/truth/completed_items.json — new hand-authored registry of 63 completed Build Route items (machine authority, Option B)
- scripts/ci_qa_scope_coverage.ps1 — new gate
- .github/workflows/ci.yml — qa-scope-coverage job added, wired into required:
- docs/truth/required_checks.json — CI / qa-scope-coverage added
- docs/truth/qa_claim.json — updated to 3.9.3
- docs/truth/qa_scope_map.json — added 3.9.3 entry
- scripts/ci_robot_owned_guard.ps1 — allowlisted 3.9.3 proof log
- docs/governance/GOVERNANCE_CHANGE_PR019.md — governance file

Proof
docs/proofs/3.9.3_qa_scope_coverage_20260221T233126Z.log

DoD
1. completed_items.json is machine authority for completed items (Option B — DEVLOG stays human-readable)
2. Gate fails if any completed item has no scope map entry, naming missing items explicitly
3. Deliberate-failure regression: removed 3.9.2 → FAIL named it → restored → PASS
4. qa_scope_map.json updated to cover all 63 completed items
5. CI green, QA approved, merged

Status: COMPLETE

2026-02-22 — Build Route v2.4 — 3.9.4 Job Graph Ordering Verification

Objective
Prove that lane-enforcement is a provable prerequisite of the docs-only-skip behavior (db-heavy) in the CI job dependency graph — closing the structural race where a governance-touching PR miscategorized as docs-only has its required governance checks skipped.

Changes
- scripts/ci_job_graph_contract.ps1 — new gate (parses ci.yml job graph, asserts db-heavy needs lane-enforcement)
- .github/workflows/ci.yml — job-graph-ordering job added, wired into required:
- docs/truth/required_checks.json — CI / job-graph-ordering added
- docs/truth/qa_claim.json — updated to 3.9.4
- docs/truth/qa_scope_map.json — added 3.9.4 entry
- docs/truth/completed_items.json — added 3.9.4
- scripts/ci_robot_owned_guard.ps1 — allowlisted 3.9.4 proof log
- docs/governance/GOVERNANCE_CHANGE_PR020.md — governance file

Proof
docs/proofs/3.9.4_job_graph_ordering_20260222T000218Z.log

DoD
1. Gate parses ci.yml job graph from needs: declarations
2. Asserts db-heavy has lane-enforcement in direct needs: (Option A)
3. Proof-only — existing CI YAML already satisfies ordering requirement
4. Gate is merge-blocking for any PR touching .github/workflows/**
5. CI green, QA approved, merged

Status: COMPLETE

2026-02-22 — Build Route v2.4 — 3.9.5 Proof Secret Scan

Objective
Harden proof:finalize to reject proof logs containing secret patterns before they enter the append-only proof chain — preventing secrets from becoming permanently embedded in manifest.json.

Changes
- docs/truth/secret_scan_patterns.json — new hand-authored pattern registry (3 patterns)
- scripts/proof_finalize.ps1 — hardened with pre-finalization secret scan
- docs/artifacts/AUTOMATION.md — documented secret scan step and pattern governance policy
- docs/artifacts/SOP_WORKFLOW.md — added Rule F documenting hardened proof:finalize behavior
- docs/governance/GOVERNANCE_CHANGE_PR021.md — governance file
- docs/truth/qa_claim.json — updated to 3.9.5
- docs/truth/qa_scope_map.json — added 3.9.5 entry
- docs/truth/completed_items.json — added 3.9.5
- scripts/ci_robot_owned_guard.ps1 — allowlisted 3.9.5 proof log

Proof
docs/proofs/3.9.5_proof_secret_scan_20260222T003447Z.log

DoD
1. secret_scan_patterns.json with 3 structural patterns only
2. proof:finalize blocks on match — prints name, line number, sanitized excerpt only
3. Deliberate-failure regression: all 3 patterns confirmed FAIL with correct output
4. False-positive regression: SHA256 hashes, manifest hashes, UTC timestamps all PASS
5. Pre-implementation check: all 3 patterns clean against existing proofs
6. No separate CI job — downstream enforcement via proof-manifest
7. CI green, QA approved, merged

Status: COMPLETE

2026-02-22 — Build Route v2.4 — Section 3.9 Bridge Closed

Objective
Verify all Section 3.9 sub-items complete and main is stable per SOP §17.

Changes
No implementation changes. Verification only.

Verification evidence
- git status: clean
- pr:preflight: PASS
- ship: PASS, zero diffs
- handoff: zero diffs (schema/contracts only — handoff_latest.txt HEAD drift expected)
- green:twice: PASS
- required_checks.json: current
- deferred_proofs.json: current (db-heavy catalogued, conversion_trigger 8.0)
- governance-path-coverage: PASS

Sub-items completed
- 3.9.1 deferred-proof-registry: COMPLETE
- 3.9.2 governance-path-coverage: COMPLETE
- 3.9.3 qa-scope-coverage: COMPLETE
- 3.9.4 job-graph-ordering: COMPLETE
- 3.9.5 proof-secret-scan: COMPLETE

Status: COMPLETE


## 2026-02-22 — Build Route v2.4 — Advisor Review: Section 4 Entry Readiness + 8.0 Stub Conversion Strategy

Objective
- Record findings from three-advisor review of Section 4 entry
  readiness and 8.0 stub conversion strategy, per SOP §14
  (advisor review findings require DEVLOG entry).

Changes
- No implementation changes. Findings and decisions only.

Proof
- Advisor review transcript (session record).
- Artifact cross-check against Build Route v2.4, CONTRACTS.md,
  GUARDRAILS.md, AUTOMATION.md, SOP_WORKFLOW.md confirmed.

DoD
- Two questions resolved with three-advisor input.
- All decisions grounded against authoritative documents.
- Build Route modifications identified and recorded in companion entry.

Findings summary

Question 1 — Section 4 entry before or after 8.0?

Three advisors reviewed. Advisors A and C: Section 4 before 8.0.
Advisor B: 8.0 first to preserve manifest integrity.

Resolution: Section 4 proceeds before 8.0. No authoritative document
prohibits Section 4 entry while stub gates are active. The deferred
proof registry (3.9.1, already on main) was designed explicitly for
this situation. Advisor B's manifest integrity concern is valid but
does not rise to a hard prohibition — it is addressed by a required
header block in every proof log finalized while stubs are active.

Adopted mitigation (Advisor B): every Section 4, 5, and 6 proof log
finalized while any stub gate remains active must include a
STUB_GATES_ACTIVE block immediately after the PR HEAD SHA line,
listing every active stub gate by name and conversion_trigger as
recorded in docs/truth/deferred_proofs.json.

Key structural reason for Section 4 first: 8.0 infrastructure design
depends on seeing real Section 4 migration shape, pgTAP structure, and
Supabase startup timing. 8.0.4 (definer-safety-audit conversion) is
hard-blocked on 6.2 hardening. 8.0.5 (pgtap conversion) is hard-blocked
on 6.3 + 6.4 test suite completion. Forcing 8.0 before Section 4
creates a circular dependency — Section 4 and 6 must inform 8.0 design,
not the other way around.

Question 2 — All five stubs in one 8.0 PR, or separate PRs?

All three advisors: separate PRs, one stub per PR.
Grounds: SOP §2 (one objective = one PR), Section 3.0 (one enforcement
surface per PR), 3.9.1 DoD item 4 (converted gate entry removed in same
PR as conversion — five separate removal events require five PRs).

Conversion order decided:
1. 8.0   — CI DB infrastructure (smoke proof only, no stubs converted)
2. 8.0.1 — clean-room-replay conversion
3. 8.0.2 — schema-drift conversion
4. 8.0.3 — handoff-idempotency conversion
5. 8.0.4 — definer-safety-audit conversion
6. 8.0.5 — pgtap conversion + database-tests.yml creation

Hard blocking dependencies:
- 8.0.4 cannot open until 6.2 hardening (pg_proc.proconfig check +
  CONTRACTS.md §8 tenant membership assertion) is on main.
- 8.0.5 cannot open until 6.3 tenant integrity suite and 6.4 RLS
  structural audit are authored, locally passing, and on main.
  A live pgtap gate with no substantive tests is a vacuous pass.

Artifact corrections identified during review:
- 4.5 (Tenancy Resolution) framing in prior advisor response was wrong.
  CONTRACTS.md §3 already locks the resolution order. 4.5 is lint
  enforcement of the locked contract, not a new decision. Build Route
  as written is correct.
- 4.4 scope: authority for core table list is CONTRACTS.md §12
  (explicit named tables), not tenant_table_selector.json. 4.4 must
  also assert authenticated has only SELECT, UPDATE on user_profiles
  per §12 controlled exception — not just anon zero privileges.
- CONTRACTS.md §13 (ALTER DEFAULT PRIVILEGES private-by-default) must
  be included in 4.4 DoD scope.
- 8.0 current DoD bundles infrastructure + all five conversions, which
  violates SOP §2. Requires Build Route amendment before any 8.0 PR opens.
- 8.0.4 conversion must assert CONTRACTS.md §8 tenant membership
  enforcement internally, not just search_path via pg_proc.proconfig.
- 8.0.5 pre-conversion audit of all pgTAP files against GUARDRAILS
  §25–28 required before stub removal.
- RELEASES.md implication: no stable release tag (11.6) is valid while
  any DB-security gate (8.0.3, 8.0.4, 8.0.5) remains a stub.

Status
- RECORDED (findings only — no gate, no proof artifact required per
  SOP §14 advisor review entry type)

---

## 2026-02-22 — Build Route v2.4 — Build Route Modifications: 8.0 Decomposition

Objective
- Record all Build Route modifications produced from the three-advisor
  review session. Per SOP §14, Build Route modifications require a
  DEVLOG entry.

Changes

Section 8 — CI Database Infrastructure

8.0 revised (DoD narrowed to infrastructure-only):
- Original DoD bundled supabase start + all five stub conversions into
  one deliverable. Violates SOP §2 and Section 3.0 one-enforcement-
  surface-per-PR rule. DoD narrowed to infrastructure smoke proof only.
- New DoD: CI workflow proves supabase start succeeds and live DB is
  reachable (SELECT 1). database-tests.yml file created (closes
  AUTOMATION.md §2 compliance gap). No stubs converted. deferred_proofs.json
  conversion triggers updated from generic "8.0" to specific 8.0.x items
  in the same PR.
- Gate: ci-db-smoke (new, merge-blocking).

8.0.1 added — clean-room-replay stub conversion:
- Converts clean-room-replay from db-heavy stub to live CI gate.
- DoD: supabase start → migrations replay → gate passes on live DB.
  Deliberate-failure test required. deferred_proofs.json entry removed.
- Gate: clean-room-replay (merge-blocking, now live).
- Prerequisite: 8.0 on main.

8.0.2 added — schema-drift stub conversion:
- Converts schema-drift from db-heavy stub to live CI gate.
- DoD: post-replay schema dump matches generated/schema.sql exactly.
  Deliberate-failure test required (introduce drift, confirm FAIL, restore).
  deferred_proofs.json entry removed.
- Gate: schema-drift (merge-blocking, now live).
- Prerequisite: 8.0.1 on main.

8.0.3 added — handoff-idempotency stub conversion:
- Converts handoff-idempotency from db-heavy stub to live CI gate.
- DoD: two consecutive handoff runs against live CI DB produce zero
  diffs. deferred_proofs.json entry removed.
- Gate: handoff-idempotency (merge-blocking, now live).
- Prerequisite: 8.0.2 on main.

8.0.4 added — definer-safety-audit stub conversion:
- Converts definer-safety-audit from db-heavy stub to live CI gate.
- DoD: gate queries pg_proc.proconfig on live catalog (not prosrc).
  Asserts search_path present for every allowlisted SD function.
  Asserts tenant membership enforcement per CONTRACTS.md §8 for every
  allowlisted SD function. deferred_proofs.json entry removed.
- Gate: definer-safety-audit (merge-blocking, now live).
- Prerequisite: 8.0.3 on main AND 6.2 hardening on main.
- HARD BLOCK: do not open until 6.2 is merged.

8.0.5 added — pgtap stub conversion:
- Converts pgtap from db-heavy stub to live CI gate. Creates
  database-tests.yml full execution (smoke job exists from 8.0; this
  wires the full test suite).
- DoD: pre-conversion audit of all pgTAP files against GUARDRAILS
  §25–28 (SQL-only, no DO blocks, no psql meta-commands, plan()/finish()
  present, no $$ anywhere). npx supabase test db passes on live CI DB.
  Suite must include 6.3 tenant integrity tests and 6.4 RLS structural
  audit — vacuous pass not acceptable. Both deferred_proofs.json entries
  removed: pgtap and database-tests.yml. deferred-proof-registry gate
  must pass after both removals.
- Gate: pgtap (merge-blocking, now live).
- Prerequisite: 8.0.4 on main AND 6.3 + 6.4 on main.
- HARD BLOCK: do not open until 6.3 and 6.4 are merged.

deferred_proofs.json trigger updates (applied in 8.0 PR):
- clean-room-replay:     8.0  → 8.0.1
- schema-drift:          8.0  → 8.0.2
- handoff-idempotency:   8.0  → 8.0.3
- definer-safety-audit:  8.0  → 8.0.4 (requires 6.2)
- pgtap:                 8.0  → 8.0.5 (requires 6.3, 6.4)
- database-tests.yml:    6.0/8.0 → 8.0.5

STUB_GATES_ACTIVE proof log header adopted (operator requirement):
- Every proof log finalized while any stub gate remains active must
  include a STUB_GATES_ACTIVE block listing active stub gates by name
  and conversion_trigger, referencing deferred_proofs.json as authority.
- This is an operator authoring requirement, not a CI gate.

Proof
- Advisor review transcript (session record).
- Three-advisor synthesis document (session record).

DoD
- 8.0 DoD revised to infrastructure-only scope.
- 8.0.1–8.0.5 defined as separate Build Route items with individual
  DoDs, prerequisites, and hard blocking dependencies.
- Conversion order locked.
- deferred_proofs.json trigger update plan recorded.
- STUB_GATES_ACTIVE header requirement documented.
- No implementation changes in this entry. Implementation begins
  with Build Route amendment governance PR, then Section 4 items.

Status
- RECORDED

## 2026-02-22 — Build Route v2.4 — Build Route Correction: 4.4 DoD Revision + STUB_GATES_ACTIVE Placement

Objective
- Correct 4.4 (anon Role Default Privilege Audit) DoD per three-advisor
  review findings, and record the authoritative placement of the
  STUB_GATES_ACTIVE operator requirement across governance artifacts.

Changes

4.4 DoD — three corrections applied:
- Core table authority changed from tenant_table_selector.json to
  CONTRACTS.md §12 named list (tenants, tenant_memberships,
  tenant_invites, deals, documents). tenant_table_selector.json is a
  product-layer artifact and does not define the security boundary.
- authenticated privilege assertion on user_profiles added: gate must
  assert authenticated holds exactly SELECT and UPDATE — no more, no
  less — per CONTRACTS.md §12 controlled exception. Over-grant and
  under-grant both fail.
- CONTRACTS.md §13 default privilege posture added to DoD scope: gate
  must query pg_default_acl to confirm no permissive default ACL exists
  for anon or authenticated on schema public. Closes the exposure window
  that 5.1 addresses at the migration layer.
- STUB_GATES_ACTIVE proof log authoring block added to 4.4 DoD as a
  one-time reminder (4.4 is the first Section 4 item; SOP Rule G is
  the ongoing authority going forward).

STUB_GATES_ACTIVE operator requirement — placement decisions:
- SOP_WORKFLOW.md Phase 4: added as Rule G immediately after Rule F
  (proof secret scan). Rule G is the single authoritative enforcement
  home for this requirement.
- AUTOMATION.md §8: explanatory note added clarifying relationship
  between the registry (machine enforcement) and the header block
  (operator authoring). CI does not enforce the block presence.
- docs/truth/deferred_proofs.json: _proof_authoring_requirement field
  added at top of object as a point-of-lookup reminder referencing
  SOP Rule G. Edit to be bundled into the 8.0 PR (where conversion
  triggers are updated from generic 8.0 to specific 8.0.1–8.0.5)
  rather than opened as a standalone PR.
- Build Route item DoDs: no further per-item additions needed beyond
  4.4. SOP Rule G is the single authority going forward. Repeating
  the requirement in every item DoD creates drift risk.

Proof
- Advisor review transcript (session record).
- Three-advisor synthesis document (session record).
- 4.4_REVISED_BUILD_ROUTE_BLOCK.md (revised 4.4 block in Build Route
  format, confirmed correct).

DoD
- 4.4 DoD corrected in Build Route: three substantive changes applied.
- STUB_GATES_ACTIVE requirement has one authoritative home
  (SOP_WORKFLOW.md Rule G) with supporting references in AUTOMATION.md
  §8 and deferred_proofs.json.
- No implementation changes in this entry. All changes are governance
  artifact updates to be committed in the next appropriate PR.

Status
- RECORDED

2026-02-22 — Build Route v2.4 — 4.3 Cloud Baseline Inventory

Objective
Extend toolchain truth with PostgREST and Auth versions captured from live cloud project, and add lane-only gate asserting versions match pinned truth.

Changes
- docs/truth/toolchain.json — extended with postgrest_version (14.1) and supabase_auth_version (v2.186.0), lane: cloud-inventory
- scripts/ci_cloud_version_pin.ps1 — new lane-only gate
- docs/truth/qa_claim.json — updated to 4.3
- docs/truth/qa_scope_map.json — added 4.3 entry
- docs/truth/completed_items.json — added 4.3
- scripts/ci_robot_owned_guard.ps1 — allowlisted 4.3 proof log
- docs/governance/GOVERNANCE_CHANGE_PR023.md — governance file

Proof
docs/proofs/4.3_cloud_baseline_inventory_20260222T173125Z.log

DoD
1. toolchain.json extended with postgrest_version and supabase_auth_version (cloud-inventory lane)
2. cloud-version-pin gate passes against live cloud project
3. PostgREST 14.1 and Auth v2.186.0 captured and pinned
4. Gate self-skips when credentials absent
5. STUB_GATES_ACTIVE block included in proof log per Rule F
6. CI green, QA approved, merged

Status: COMPLETE

2026-02-XX — Build Route v2.4 — 4.4 DoD Clarification

Objective
Clarify pg_default_acl scope for platform-managed roles.

Changes
Amended 4.4 DoD to scope default ACL cleanliness to operator-owned roles (postgres + app roles).
Explicitly excluded supabase_% roles with materialization proof requirement.

Proof
Advisor escalation ruling documented.
Governance change PR merged.

DoD
4.4 gate now evaluates:
- Direct grants
- Operator-owned default ACL entries
- Materialization proof for platform-owned roles

Status
RECORDED

2026-02-22 — Build Route v2.4 — 4.4 anon Role Default Privilege Audit

Objective
Prove anon holds zero privileges on all core tables, authenticated holds exactly the CONTRACTS.md §12 controlled exception on user_profiles, and operator-owned default privileges are private-by-default.

Changes
- supabase/migrations/20260219000004_default_acl_lockdown.sql — default ACL lockdown (postgres role)
- supabase/migrations/20260219000005_privilege_remediation.sql — stop-the-line: revoke materialized grants + re-apply controlled exception
- generated/schema.sql — regenerated via handoff
- docs/truth/anon_privilege_truth.json — machine-derived privilege truth
- scripts/ci_anon_privilege_audit.ps1 — new merge-blocking gate (psql, pooler, DB/runtime lane)
- .github/workflows/ci.yml — anon-privilege-audit job added, wired into required:
- docs/truth/required_checks.json — CI / anon-privilege-audit added
- docs/truth/qa_claim.json — updated to 4.4
- docs/truth/qa_scope_map.json — added 4.4 entry
- docs/truth/completed_items.json — added 4.4
- scripts/ci_robot_owned_guard.ps1 — allowlisted 4.4 proof log
- docs/governance/GOVERNANCE_CHANGE_PR025.md — governance file

Stop-the-line
CONTRACTS.md §12 privilege firewall violation detected via catalog audit before gate ran. anon and authenticated had full object-level grants on all core tables (materialized from supabase_admin default ACL). Remediated via migration 20260219000005 before gate implementation proceeded.

Decisions
- supabase_% roles excluded from default ACL cleanliness requirement per GOVERNANCE_CHANGE_PR024.md
- Carve-out invalidated by materialization — remediation required before 4.4 could proceed
- Gate uses psql via CI + Supabase Session Pooler (IPv4) — direct DB host is IPv6-only

Proof
docs/proofs/4.4_anon_privilege_audit_20260223T032332Z.log

DoD
1. Zero anon grants on all core tables — CONFIRMED
2. authenticated has exactly SELECT+UPDATE on user_profiles — CONFIRMED
3. Zero anon/authenticated sequence and routine grants — CONFIRMED
4. Operator-owned default ACL clean — CONFIRMED
5. Platform ACL logged, not enforced per GOVERNANCE_CHANGE_PR024.md
6. CI green, QA approved, merged

Status: COMPLETE

2026-02-23 — Build Route v2.4 — 4.5 Tenancy Resolution Contract Enforcement

Objective
Mechanically detect forbidden tenant resolution patterns in migrations — closing the path where raw auth.uid() or inline JWT claim parsing for tenant ID bypasses the approved resolution helper per CONTRACTS.md §3.

Changes
- scripts/ci_rls_strategy_lint.ps1 — new merge-blocking gate (static analysis, migration lane)
- .github/workflows/ci.yml — rls-strategy-consistent job added, wired into required:
- docs/truth/required_checks.json — CI / rls-strategy-consistent added
- docs/truth/qa_claim.json — updated to 4.5
- docs/truth/qa_scope_map.json — added 4.5 entry
- docs/truth/completed_items.json — added 4.5
- scripts/ci_robot_owned_guard.ps1 — allowlisted 4.5 proof log
- docs/governance/GOVERNANCE_CHANGE_PR026.md — governance file

Proof
docs/proofs/4.5_tenancy_resolution_enforcement_20260223T153240Z.log

DoD
1. Gate detects raw auth.uid() in RLS policy body — CONFIRMED
2. Gate detects raw auth.jwt() in RLS policy body — CONFIRMED
3. Gate detects inline JWT claim parsing for tenant ID — CONFIRMED
4. Gate fails naming file, policy, line number, CONTRACTS.md §3
5. Deliberate-failure regression confirmed
6. 6 migrations scanned — zero violations
7. CI green, QA approved, merged

Status: COMPLETE

2026-02-23 — Build Route v2.4 — 2.16.1 Policy Drift Attestation Remediation

Objective
Restore policy-drift-attestation scheduled workflow to green after silent failure period beginning ~2026-02-10.

Changes
- PR027: scripts/policy_drift_attest.mjs — catch 403 on branch protection API (repo ownership change)
- PR028: docs/truth/github_policy_snapshot.json — regenerated after ownership transfer
- PR029: scripts/policy_drift_attest.mjs — added BRANCH= line to output (workflow requirement)
- PR030: .github/workflows/policy-drift-attestation.yml — removed git push steps (attestation-only per QA ruling Option 3)
- docs/governance/GOVERNANCE_CHANGE_PR027-030.md — governance files for each fix

Root cause
Repo ownership transfer ~2026-02-10 caused: (1) branch protection API returning 403 instead of 404, (2) snapshot divergence, (3) workflow attempting direct push to main which branch ruleset blocks. All three were silent failures — scheduled workflow failed without alerting.

Resolution
Four sequential PRs (PR027-PR030) resolved each failure. Workflow redesigned to attestation-only — no self-commit to main. First clean manual dispatch run confirmed GREEN 2026-02-23.

QA ruling
Option 3 approved — remove git push, attestation-only. Options 1 (bot bypass) and 2 (side branch) rejected as non-compliant.

Status: COMPLETE

---

## 2026-02-23 — Build Route v2.4 — Advisor Review: CI Execution Surface & Schema Drift Dependency Resolution

**Objective** Record findings from three-advisor review regarding CI DB execution surfaces, IPv4 provisioning, and the structural resolution of the Section 6/8 schema-drift dependency trap, per SOP §14.

**Changes** - No implementation changes. Findings and decisions only.

**Proof** - Advisor review transcript (session record).

* Artifact cross-check against Build Route v2.4, CONTRACTS.md, and AUTOMATION.md confirmed.

**DoD** - Three-advisor input reconciled against locked prerequisite chains.

* All decisions grounded against authoritative documents.
* Build Route modifications identified and recorded in findings summary.

**Findings Summary**

**1. CI Execution Surface Contract (Two-Tier Model)**

* **Finding:** Transaction-mode poolers silently drop session-level state, which breaks RLS fallbacks and session-dependent tests.
* **Decision:** Formalize a Two-Tier CI Execution Contract (Tier 1: Pooler/Stateless, Tier 2: Direct/Sessionful). Tier 1 explicitly bans `SET`, `SET LOCAL`, temporary tables, advisory locks, and prepared statements/cursors. Existing gates (4.4 and 4.5) are explicitly grandfathered as Tier 1.
* **Action:** Add Build Route Item 4.6.

**2. Direct IPv4 Provisioning**

* **Finding:** Direct database access is a hard prerequisite for the populated-data negative tests in Section 6.3, but is not strictly required for Section 6.1 entry.
* **Decision:** Provision direct IPv4 access before Section 6 to unblock future Tier-2 session-state tests. Capture the direct host in `docs/truth/toolchain.json`.
* **Action:** Add Build Route Item 5.2.

**3. The `schema-drift` Circular Dependency Trap**

* **Finding:** Pulling `schema-drift` (8.0.2) forward is structurally unexecutable because 8.0.2 explicitly requires `clean-room-replay` (8.0.1) on `main`, which requires a completed migration set.
* **Decision:** Do not pull Section 8 forward. Instead, prevent schema drift during Section 6 migration authoring via two separate mechanisms:
1. A static CI coupling gate ensuring `generated/schema.sql` is updated whenever migrations change (Guarantee A).
2. A local ephemeral replay proof (operator script) demonstrating schema correctness against a live point-in-time database (Guarantee B).


* **Action:** Add Build Route Item 5.3 (Static Migration-Schema Coupling). Harden Item 6.1 DoD to require the local ephemeral replay proof for all migration PRs.

**4. `pgtap` Vacuous Pass & Workflow Compliance Gap**

* **Finding:** `pgtap` (8.0.5) must remain locked until 6.3 and 6.4 are merged to prevent merging an empty test suite (a vacuous pass).
* **Decision:** To close the `AUTOMATION.md §2` compliance gap atomically, 6.3 must explicitly create the `.github/workflows/database-tests.yml` file alongside the first real tests.
* **Action:** Harden Item 6.3 DoD to explicitly require the creation of the workflow and the simultaneous update of the `deferred_proofs.json` triggers for both `database-tests.yml` and `pgtap` to `"6.3"`.

**Status** RECORDED

2026-02-24 — Build Route v2.4 — 4.6 Two-Tier CI Execution Contract

Objective
Formalize machine-readable contract defining Tier 1 (Pooler/Stateless) and Tier 2 (Direct/Sessionful) CI execution constraints to prevent session-state tests from silently failing against the pooler.

Changes
- docs/truth/ci_execution_surface.json — new Two-Tier CI Execution Contract
- scripts/truth_bootstrap_check.mjs — registered ci_execution_surface.json
- scripts/ci_robot_owned_guard.ps1 — registered ci_execution_surface.json + 4.6 proof log allowlist
- docs/truth/qa_claim.json — updated to 4.6
- docs/truth/qa_scope_map.json — added 4.6 entry
- docs/truth/completed_items.json — added 4.6
- docs/governance/GOVERNANCE_CHANGE_PR032.md — governance file

Proof
docs/proofs/4.6_two_tier_execution_contract_20260224T002145Z.log

DoD
1. ci_execution_surface.json exists with version + tiers keys — CONFIRMED
2. Tier 1 ban list defined: SET, SET LOCAL, temp tables, advisory locks, prepared statements, cursors
3. Gates 4.4 and 4.5 grandfathered as Tier 1 — CONFIRMED
4. Tier 2 defined — requires Item 5.2 IPv4 provisioning
5. Triple Registration Rule satisfied
6. CI green, QA approved, merged

Status: COMPLETE

2026-02-24 — Build Route v2.4 — 4.7

Objective
Introduce Tier-1 Gate Surface Normalization to eliminate embedded-only enforcement topology and ensure every Tier-1 CI gate declared in ci_execution_surface.json is represented as a top-level merge-blocking job explicitly wired into the required aggregator.

Changes
- Identified that certain Tier-1 gates (e.g., truth-bootstrap) executed as steps within broader jobs rather than standalone jobs.
- Confirmed enforcement was technically correct but topology visibility was ambiguous.
- Added Build Route item 4.7 to formalize normalization of Tier-1 gate surface.
- Defined constraints: no logic changes, no enforcement semantic changes, no required-check renames.
- Established deterministic DoD and proof requirements for CI topology clarity.

Proof
This DEVLOG entry records governance rationale only.
Implementation and proof artifact for 4.7 will be produced in the objective PR for 4.7.

DoD
- 4.7 defined in Build Route with clear Deliverables, DoD, Proof, and Gate.
- Governance rationale recorded prior to implementation.
- No CI behavior modified at time of entry.

Status
Planned (Pre-Implementation Governance Hardening)

2026-02-24 — Build Route v2.4 — 4.7 Tier-1 Gate Surface Normalization

Objective
Verify that every Tier-1 CI gate declared in ci_execution_surface.json is implemented as a top-level merge-blocking job explicitly wired into the required aggregator.

Changes
- docs/truth/qa_claim.json — updated to 4.7
- docs/truth/qa_scope_map.json — added 4.7 entry
- docs/truth/completed_items.json — added 4.7
- scripts/ci_robot_owned_guard.ps1 — allowlisted 4.7 proof log
- docs/governance/GOVERNANCE_CHANGE_PR034.md — governance file

Finding
All Tier-1 gates already normalized — no ci.yml changes required.
- anon-privilege-audit: standalone top-level job, in required: needs
- rls-strategy-consistent: standalone top-level job, in required: needs
truth-bootstrap: out of scope — static truth validation, no DB access

Proof
docs/proofs/4.7_tier1_surface_normalization_20260224T014009Z.log

DoD
1. All declared Tier-1 gates are top-level jobs — CONFIRMED
2. All declared Tier-1 gates are in required: needs — CONFIRMED
3. No embedded-only Tier-1 DB gates found — CONFIRMED
4. No ci.yml changes required — CONFIRMED
5. CI green, QA approved, merged

Status: COMPLETE

2026-02-24 — Build Route v2.4 — 5.0 Required Gates Inventory

Objective
Harden the required gates inventory DoD to establish rules for future gate registrations and confirm current registration state.

Changes
- docs/truth/qa_claim.json — updated to 5.0
- docs/truth/qa_scope_map.json — added 5.0 entry
- docs/truth/completed_items.json — added 5.0
- scripts/ci_robot_owned_guard.ps1 — allowlisted 5.0 proof log
- docs/governance/GOVERNANCE_CHANGE_PR035.md — governance file

Finding
- anon-privilege-audit: registered in 4.4 PR — CONFIRMED
- rls-strategy-consistent: registered in 4.5 PR — CONFIRMED
- migration-rls-colocation: not yet registered — CI job does not exist yet (5.1)
- unregistered-table-access: not yet registered — CI job does not exist yet (6.3A)
- calc-version-registry: not yet registered — CI job does not exist yet (7.6)

Hardened DoD rules
- Gates registered in required_checks.json only in the PR that creates the corresponding CI job
- No gate registered before CI job exists string-exact in .github/workflows/**
- Each registration PR triggers governance-change-guard + governance file
- npm run truth:sync required in each registration PR

Proof
docs/proofs/5.0_required_gates_inventory_20260224T021851Z.log

DoD
1. Current registrations confirmed correct — CONFIRMED
2. Future registration rules established — CONFIRMED
3. CI green, QA approved, merged

Status: COMPLETE

2026-02-24 — Build Route v2.4 — 5.1 Migration RLS Co-location Lint

Objective
Introduce merge-blocking gate that fails if any migration creates a table without enabling RLS and revoking default privileges in the same file — closing the partial-migration exposure window.

Changes
- supabase/migrations/20260219000006_rls_colocation_corrective.sql — corrective migration per 5.1 pre-check
- scripts/ci_migration_rls_lint.ps1 — new merge-blocking gate (migration lane, static analysis)
- .github/workflows/ci.yml — migration-rls-colocation job added, wired into required:
- docs/truth/required_checks.json — CI / migration-rls-colocation added
- docs/truth/qa_claim.json — updated to 5.1
- docs/truth/qa_scope_map.json — added 5.1 entry
- docs/truth/completed_items.json — added 5.1
- scripts/ci_robot_owned_guard.ps1 — allowlisted 5.1 proof log
- docs/governance/GOVERNANCE_CHANGE_PR036.md — governance file
- generated/schema.sql — regenerated via handoff

Pre-check finding
All 4 baseline tables (tenants, tenant_memberships, user_profiles, deals) failed co-location rule. RLS and REVOKEs applied in later migrations, not same-file as CREATE TABLE. Corrective migration 20260219000006 authored and merged before gate activation per Build Route 5.1 DoD.

Gate design
- Enforces same-file co-location for migrations >= 20260219000006 (baseline remediation boundary)
- Pre-cutoff migrations skipped — documented exemption
- Fails naming: migration file, table name, missing statement
- Deliberate-failure regression confirmed

Proof
docs/proofs/5.1_migration_rls_colocation_20260224T025517Z.log

DoD
1. Gate detects missing RLS on CREATE TABLE — CONFIRMED
2. Gate detects missing REVOKE anon — CONFIRMED
3. Gate detects missing REVOKE authenticated — CONFIRMED
4. Pre-cutoff migrations skipped — CONFIRMED
5. Corrective migration merged before gate activation — CONFIRMED
6. CONTRACTS.md §12 controlled exception preserved — CONFIRMED
7. CI green, QA approved, merged

Status: COMPLETE

2026-02-24 — Build Route v2.4 — 5.2 Direct IPv4 Provisioning — DEFERRED

Objective
Establish direct DB connectivity to unblock future Tier-2 session-state tests.

Finding
GitHub Actions Ubuntu runner cannot reach direct DB host (db.upnelewdvbicxvfgzojg.supabase.co:5432) via IPv6 — Network is unreachable. Local machine also IPv6-only. Direct connectivity requires Supabase IPv4 add-on (paid).

Deferral rationale
- Business-stage sequencing — no current requirement for CI session-state enforcement
- Tier-2 gates inactive/stubbed as documented in ci_execution_surface.json
- IPv4 provisioning to be activated 30-60 days before launch

Next milestone
Revisit at Build Route Item 11.0 (launch hardening) before:
- Activation of Tier-2 DB tests
- Removal of db-heavy stub"

Actions taken
- IPv6 connectivity test confirmed FAIL from GitHub Actions
- Temporary test workflow NOT merged to main
- No CI jobs depend on direct-host connectivity
- Foundation architecture unchanged

Status: DEFERRED


Here is a clean, governance-aligned DEVLOG entry:

---

## DEVLOG — Addition of Section 11.10 (Lean Runtime Operations Baseline)

### Context

After completing foundation hardening (Sections 1–9) and sequencing UI build (Section 10), it became clear that the Build Route lacked a minimal runtime operations baseline prior to launch.

Earlier drafts leaned toward enterprise-grade operational governance. Given current stage (pre-launch, zero production tenants), that level of enforcement was misaligned with product maturity.

Section 11.10 was introduced to establish:

* Minimal runtime observability
* Defined reliability targets
* Basic abuse safeguards
* Emergency containment capability
* Explicit data lifecycle invariants

Without introducing premature enterprise complexity.

---

### Intent

11.10 formalizes runtime invariants without:

* Introducing heavy merge-blocking telemetry gates
* Requiring enterprise-grade incident bureaucracy
* Creating operational theater before user scale

It ensures:

* Mechanical clarity
* Explicit contracts
* Upgrade path to stricter enforcement post-scale

---

### Architectural Principle

Foundation governs build-time invariants.
Section 11.10 governs runtime invariants.

This separates:

* Compile-time safety (RLS, migrations, CI gates)
  from
* Runtime safety (telemetry, SLOs, rate limits, kill switches)

---

### Scope Discipline

All 11.10 gates are:

* Presence + schema validation only
* Alert-only (non-blocking)
* Upgradable when production exposure increases

This preserves launch velocity while preventing undefined runtime behavior.

---

### Strategic Rationale

The system is designed as a reusable multi-product foundation.
Runtime contracts must exist before scale, but enforcement intensity must match stage.

11.10 establishes the floor, not the ceiling.

---

End of entry.

2026-02-24 — Build Route v2.4 — 5.3 Static Migration-Schema Coupling Gate

Objective
Introduce merge-blocking gate ensuring generated/schema.sql is updated whenever migrations change — enforcing static coupling without requiring a live CI DB.

Changes
- scripts/ci_migration_schema_coupling.ps1 — new merge-blocking gate (static diff analysis)
- .github/workflows/ci.yml — migration-schema-coupling job added, wired into required:
- docs/truth/required_checks.json — CI / migration-schema-coupling added
- docs/truth/qa_claim.json — updated to 5.3
- docs/truth/qa_scope_map.json — added 5.3 entry
- docs/truth/completed_items.json — added 5.3
- scripts/ci_robot_owned_guard.ps1 — allowlisted 5.3 proof log
- docs/governance/GOVERNANCE_CHANGE_PR038.md — governance file

Gate behavior
- Migrations changed + schema not updated: FAIL with handoff + handoff:commit remediation
- Migrations changed + schema updated: PASS
- No migration changes: SKIP (PASS)
- Skip logic: file path match on supabase/migrations/** (not SQL diff)
- Schema target: exact canonical path generated/schema.sql

Proof
docs/proofs/5.3_migration_schema_coupling_20260224T172411Z.log

DoD
1. Gate detects migrations changed without schema update — CONFIRMED
2. Gate skips when no migration changes — CONFIRMED
3. Remediation message includes handoff + handoff:commit — CONFIRMED
4. Deliberate-failure regression confirmed — CONFIRMED
5. CI green, QA approved, merged

Status: COMPLETE

## 2026-02-24 — Section 5 Closure (Governance Gates)

### QA Determination

Section 5 — Governance Gates (CI required-now) is formally closed.

The following items are complete and merge-blocking:

* 5.0 — Required Gates Inventory (Hardened registration discipline)
* 5.1 — Migration RLS Co-location Lint (merge-blocking)
* 5.3 — Static Migration-Schema Coupling Gate (merge-blocking)

All gates are:

* Registered in `docs/truth/required_checks.json`
* Wired into CI `required:` surface
* Backed by canonical proof artifacts
* Green on `main`

---

### Deferred Item

* 5.2 — Direct IPv4 Provisioning

Status: **Deferred**

Rationale:
Direct IPv4 provisioning is required only to activate Tier-2 session-state tests. Current project phase (UI build, pre-launch) does not require CI direct DB connectivity. Activation moved to:

**11.0 — Activate Direct IPv4 Provisioning (Pre-Launch Hardening)**

Architectural intent preserved.
Execution timing staged.

---

### Integrity Check

Section 5 now enforces:

* No unregistered gate drift (5.0)
* No partial RLS migrations (5.1)
* No schema artifact desynchronization (5.3)

This closes the migration and schema governance surface prior to UI construction.

No advisor review required.
No enforcement philosophy changed.
No gate weakened or removed.

---

### Status

Section 5 marked COMPLETE (with 5.2 deferred to 11.0).

Proceeding to Section 6.

---

End of entry.

## 2026-02-25 — Build Route v2.4 — 6.1 Greenfield Baseline Migrations

Objective
Prove baseline migrations are authored new (REBUILD MODE), enforce local ephemeral replay proof as a precondition of the handoff publisher, and establish mechanical enforcement so migration PRs cannot bypass proof requirement.

Changes
- scripts/handoff.ps1 — 6.1 enforcement block added: detects migration changes (committed, staged, worktree) and exits non-zero with "6.1 REPLAY PROOF REQUIRED" before writing any truth artifacts if no valid replay proof log exists
- docs/truth/qa_claim.json — updated to 6.1
- docs/truth/qa_scope_map.json — added 6.1 entry
- docs/truth/completed_items.json — added 6.1
- scripts/ci_robot_owned_guard.ps1 — allowlisted 6.1 proof log pattern
- docs/governance/GOVERNANCE_CHANGE_PR039.md — governance file
- docs/proofs/6.1_greenfield_baseline_migrations_20260225T012204Z.log — canonical proof log (proof repair PR closed stale log from original PR)

Proof
docs/proofs/6.1_greenfield_baseline_migrations_20260225T012204Z.log

DoD
1. Baseline migrations exist, authored new (no legacy import) — CONFIRMED (20260219000000–20260219000006)
2. Local ephemeral replay: supabase db reset → migrations applied in order → handoff → git diff --exit-code = 0 — CONFIRMED
3. Enforcement: handoff exits non-zero with exact message when migrations changed and no proof log present — CONFIRMED (exit code 1)
4. PROOF_HEAD consistent across proof log header and body — CONFIRMED
5. CI green, QA approved, merged

Status
PASS


## 2026-02-25 — Build Route v2.4 — 6.1A Handoff Preconditions Hardening

Objective

Establish DB-state precondition gate enforcing catalog invariants before truth artifact generation.

Changes

Added scripts/ci_handoff_preconditions.ps1 (live DB catalog validation).

Wired preconditions into scripts/handoff.ps1 to execute before schema/contracts/handoff_latest writes.

Added CI job handoff-preconditions (merge-blocking, docs-only skip).

Updated truth artifacts (qa_claim.json, qa_scope_map.json, required_checks.json, completed_items.json).

Added governance record GOVERNANCE_CHANGE_PR040.md.

Proof

PASS path: preconditions PASS before any truth artifact writes.

FAIL path: invariant mismatch (public.deals.tenant_id nullable) blocks writes; before/after hashes identical.

Canonical proof: docs/proofs/6.1A_handoff_preconditions_<UTC>.log.

DoD

DB-state gate exists and validates tables, columns, and RLS via live catalog.

Preconditions execute before any truth artifact generation.

Handoff exits non-zero and does not overwrite truth artifacts on failure.

Failure output reports expected vs found state.

CI job id handoff-preconditions exists and is merge-blocking.

Status

PASS
## 2026-02-26 — Build Route v2.4 — 6.2 SECURITY DEFINER Safety [HARDENED]

Objective
Prove every SECURITY DEFINER function is allowlisted, audited against catalog-level safety invariants (pg_proc.proconfig, not pg_proc.prosrc), and that gate scope is restricted to application schemas only (public, rpc).

Changes
- scripts/ci_definer_safety_audit.ps1 — rewritten: scope restricted to public/rpc, allowlist cross-reference added, pg_proc.proconfig catalog check added, CI stub added
- .github/workflows/ci.yml — definer-safety-audit job added, wired into required
- docs/truth/required_checks.json — CI / definer-safety-audit added (truth:sync ordering applied)
- docs/truth/completed_items.json — 6.2 added
- docs/truth/qa_claim.json — updated to 6.2
- docs/truth/qa_scope_map.json — 6.2 entry added
- scripts/ci_robot_owned_guard.ps1 — 6.2 proof log pattern allowlisted
- docs/governance/GOVERNANCE_CHANGE_PR041.md — Build Route 6.2 update governance record
- docs/governance/GOVERNANCE_CHANGE_PR042.md — 6.2 implementation governance record

Proof
docs/proofs/6.2_definer_audit_20260226T000338Z.log

DoD
- SD functions allowlisted and audit passes — CONFIRMED (zero application SD functions; allowlist correctly empty)
- definer-safety-audit gate checks pg_proc.proconfig for search_path entry — CONFIRMED
- Gate fails naming function and missing proconfig entry — CONFIRMED
- Helper function enumeration in proof — CONFIRMED (none to enumerate at baseline)
- Gate scoped to public/rpc only; system schemas excluded — CONFIRMED
- CI stub registered in deferred_proofs.json (converts at 8.0.4) — CONFIRMED
- CI green, QA approved, merged

Status
PASS