# DEVLOG (Authoritative)
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

