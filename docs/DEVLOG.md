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

## 2026-02-07 — **1.3 Denylist Verification (P2)**

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

## 2026-02-07 — **1.4 Regenerate-Only Policy (P3)**

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

## 2026-02-07 — **1.5 Document Corrections (Mandatory)**

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

## 2026-02-07 — **2.1 Repo Bootstrap**

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