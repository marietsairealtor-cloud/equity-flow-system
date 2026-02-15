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
- CI job oundation-invariants (triggered by supabase/foundation/**) + required-checks truth sync
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


