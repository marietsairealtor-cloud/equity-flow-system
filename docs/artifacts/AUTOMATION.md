# AUTOMATION.md
Authoritative — CI & Mechanical Enforcement (Aligned with Command + GUARDRAILS)

---

## 0) Purpose

This document defines what CI enforces mechanically.

- Build Route defines what must be true.
- Command for Chat defines execution discipline.
- GUARDRAILS defines non-negotiable safety rules.
- AUTOMATION defines enforcement behavior.

If conflict exists:
Build Route wins.
Command for Chat wins.
GUARDRAILS wins.
Automation must be updated via PR.

---

## 1) Completion Enforcement (Merge Blocking)

An objective is complete ONLY if:

PR opened → CI green → approved → merged

CI must block merge if:
- Any required check is red
- Required approvals are missing (branch protection)
- Required workflows did not execute

No merge on red.
No bypass.
No partial objective merges.

---

## 2) Required Workflows (Merge Blocking)

The following workflows are required and merge-blocking:

- `.github/workflows/ci.yml`
- `.github/workflows/database-tests.yml`
- `.github/workflows/secrets-scan.yml`
- `.github/workflows/stop-the-line.yml`

NOTE: CI topology is structurally enforced by the merge-blocking gate `ci-topology-audit` (enforcement only; not a policy authority source).

If any required workflow fails → merge blocked.

---

## 3) CI Lane Isolation (Deterministic)

CI must enforce deterministic PR lanes.

### 3.1 Docs-only PR
Trigger: only `docs/**` changes (excluding robot artifacts)

Must:
- Skip DB-heavy workflows
- Skip pgTAP
- Skip migration replay

May run:
- Lint
- Non-DB safety checks

---

### 3.2 Artifacts-only PR
Trigger: only robot-owned outputs (`docs/proofs/**`, generated snapshots)

Must run:
- schema drift gate
- policy gate
- proof-commit-binding

Must skip:
- pgTAP
- migration replay
- full DB suite

---

### 3.3 Code / Migration PR
Any functional change.

Must run full CI:
- schema drift
- policy validation
- DB tests / pgTAP
- migration replay
- proof-commit-binding
- secrets scan
- stop-the-line

If workflow YAML does not enforce this, repository is noncompliant.

---

## 4) Proof-Commit-Binding Enforcement

CI must validate the integrity of proof artifacts.

### 4.1 PROOF_HEAD
- Must equal tested SHA at runtime
- Must be ancestor of PR_HEAD
- Commits after PROOF_HEAD may modify only:
  - docs/proofs/**
  - optionally docs/DEVLOG.md

Violation → FAIL

---

### 4.2 PROOF_SCRIPTS_HASH
Must be:
- Deterministic
- Explicit file list (no globbing)
- Deterministic ordering
- CRLF normalized to LF before hashing

Hash must match between:
- AUTOMATION.md specification
- Validator implementation
- Proof log header

Mismatch → FAIL

---

## 5) Guardrail Enforcement (Per GUARDRAILS.md)

CI must enforce:

- Encoding/BOM validation (UTF-8 no BOM, LF only)
- SQL safety lint
- No `$$` in repo-owned SQL (named tags only)
- No dynamic SQL in migrations
- No retro-editing historical migrations
- Schema drift detection
- Policy snapshot coupling
- SECURITY DEFINER safety (fixed search_path, no dynamic SQL)
- Absolute path prohibition in manifests
- Secrets-scan gate enforcement

Any guardrail failure → stop-the-line.

---

## 6) Stop-The-Line Acknowledgment (XOR Rule)

If stop-the-line triggers:

Exactly one acknowledgment must exist:

- INCIDENT entry in `docs/threats/INCIDENTS.md`
  OR
- One-PR waiver file `docs/waivers/WAIVER_PR<NNN>.md`
  containing exact text: `QA: NOT AN INCIDENT`

Both present = FAIL
None present = FAIL

Merge blocked until condition satisfied.

---

## 7) Execution Surface Stability (Referenced Authority)

CI assumes execution surface stability per Command for Chat:

- No shell changes mid-objective
- No runtime swaps mid-objective
- No new runtime introduced mid-item

If proof artifacts imply execution surface drift,
proof-binding validation may fail.

Execution surface changes require a new objective.

---

## 8) Truth Artifact Enforcement

CI must fail if:

- Robot-owned files are manually edited
- Generated files differ from expected deterministic output
- Manifest paths violate POSIX-only requirement
- Absolute paths are introduced

Truth artifacts must be commit-bound and reproducible.

(`handoff`/`handoff:commit` generation path enforcement deferred until implemented.)

---

## 9) Waiver Debt Enforcement (Build Route 2.16.4)

If waivers are used:

- Must be recorded in-repo
- Must be time-bounded
- Must be scoped
- Expired waivers must fail CI

Waiver removal requires:
PR opened → CI green → approved → merged

CI blocks merge if:
- Waiver expired
- Waiver undocumented
- Waiver scope mismatch

---

## 10) Branch Protection Assumptions

- `main` is PR-only
- No direct pushes
- Required reviews enforced
- Required checks string-exact match GitHub status contexts

If branch protection is misconfigured, governance is degraded.

---

## 11) Governance Integrity Guarantees

Automation enforces mechanics only.

It does not:
- Infer missing proof
- Redesign system
- Allow partial objectives
- Permit CI bypass

One objective = one PR.
Merge only when CI green and approved.

---

STATUS:
Aligned with Command for Chat
Aligned with Build Route v2.4
Aligned with GUARDRAILS
Stop-the-line XOR enforced
Proof-binding deterministic
Lane isolation defined
Approval-before-merge enforced
Governance stack mechanically consistent

---

### proof-commit-binding — scripts hash authority

**Authority:** This section is the single source of truth for `PROOF_SCRIPTS_HASH`.

**Script file list (string-exact, no globbing):**
- `scripts/ci_proof_commit_binding.ps1`

**Ordering rule:**
- Hash files in the list order shown above.

**Normalization rule (before hashing):**
- Read file as UTF-8 (no BOM).
- Normalize line endings: CRLF (`\r\n`) → LF (`\n`); lone CR (`\r`) → LF (`\n`).

**Hash input framing:**
- For each file in order, concatenate:
  - `FILE:<relpath>\n`
  - normalized file text
  - `\n`
- Compute SHA-256 of the concatenated UTF-8 bytes.
- Encode as lowercase hex.

**Parser contract (LOCKED):**
- Start marker: `### proof-commit-binding — scripts hash authority`
- Bullet pattern: `- \`relpath\`` (no extra text)
- End marker: `END scripts hash authority`

END scripts hash authority
