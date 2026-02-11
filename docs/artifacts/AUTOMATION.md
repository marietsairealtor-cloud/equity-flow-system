# AUTOMATION.md

Authoritative — Merge Blocking

## Purpose

Defines automated enforcement of governance, proof discipline, CI behavior, and release integrity.

Automation enforces contracts. Humans do not bypass gates.

---

# 1. Command Contracts (Authoritative)

## 1.1 `handoff`

* Generates truth artifacts
* Updates snapshots
* Writes `docs/handoff_latest.txt`
* Does NOT commit
* Does NOT push

## 1.2 `handoff:commit`

* Commits only robot-owned artifacts
* Creates PR branch if on `main`
* Never commits to `main`
* Never commits human-authored files

## 1.3 `ship`

* Verify-only publisher
* Must run on clean `main`
* Runs gates locally
* Must NOT generate artifacts
* Must NOT commit human code
* If any gate fails → treat as regression → new PR required

---

# 2. CI Workflow Architecture

## 2.1 Core CI Workflows (Authoritative)

These are merge-blocking:

* `.github/workflows/ci.yml`
* `.github/workflows/database-tests.yml`
* `.github/workflows/secrets-scan.yml`
* `.github/workflows/stop-the-line.yml`

If any fail → merge blocked.

---

# 3. CI Lane Isolation Rules

## 3.1 Docs-only PR

Trigger: only `docs/**`

Must:

* Skip database CI
* Skip pgTAP
* Skip migration replay

Must run:

* Lint (if configured)

---

## 3.2 Artifacts-only PR

Trigger: only robot artifacts (`docs/proofs/**`, snapshots)

Must run:

* `ci_schema_drift`
* `ci_policy`
* lint (if configured)

Must skip:

* pgTAP
* full DB replay
* migration tests

---

## 3.3 Code / Migration PR

Trigger: any non-doc, non-artifact change

Must run full CI:

* schema drift
* policy gate
* pgTAP
* migration replay
* proof-commit-binding
* secrets scan
* stop-the-line

---

# 4. Proof Enforcement

## 4.1 Completion Law

Objective is complete ONLY if:
PR opened → CI green → merged

No PR = Not Done
Passing tests without PR = Not Done
One objective = One PR

---

## 4.2 Proof-Only Work Rule

If no functional change:
A Proof PR is still required.

Must include at least one:

* committed proof log
* pgTAP assertion
* DEVLOG update with evidence

“Nothing to commit” = invalid

Proof must exist in-repo under:
`docs/proofs/**`

Out-of-branch proof = invalid

---

# 5. Guardrails

Automation enforces:

* Encoding/BOM validation
* SQL safety lint
* Schema drift detection
* Policy snapshot coupling
* Definer safety audit (if applicable)

If guardrail fails → stop-the-line.

---

# 6. Proof-Commit Binding

CI verifies:

* Proof artifacts correspond to actual commit state
* Hashes match authoritative source
* Snapshots not manually edited

Violation = immediate failure.

---

# 7. Release Model

Proof ≠ Publish ≠ Release

All changes flow:
PR → CI green → Merge

After merge:

* checkout main
* git pull
* git status must be clean
* run `ship`
* all local gates must pass

If not clean → lane not closed.

---

# 8. Stop-The-Line Policy

If:

* CI red
* Guardrail violation
* Drift detected
* Snapshot mismatch

Then:
No merge.
No bypass.
Fix first failing gate only.

---

# 9. Non-Negotiables

* Robot-owned files are never hand-edited.
* No manual CI reruns to “make green.”
* No merging on red.
* No partial objective merges.
* No multi-objective PRs.

---

### proof-commit-binding — scripts hash authority

**Authority:** This section is the single source of truth for `PROOF_SCRIPTS_HASH`.

**Script file list (string-exact, no globbing):**
- `scripts\ci_proof_commit_binding.ps1`

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
- Start marker: ### proof-commit-binding — scripts hash authority
- Bullet pattern: - `relpath` (no extra text)
- End marker: END scripts hash authority
END scripts hash authority
