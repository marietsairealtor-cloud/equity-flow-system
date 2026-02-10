# SOP — Local Proof + CI Proof (WeWeb + Supabase)

## Purpose

Prevent regressions through repeatable proofs and strict role separation.

This SOP defines how work is proven locally, how truth artifacts are generated and published, how releases are verified, and what “done” means.

---

* Proof artifacts must be committed under `docs/proofs/` (never `logs/`).
* Any newly created proof file must pass `npm run fix:encoding` before commit.

---

## Core Principle (LOCKED)

### There Is No Golden Path

The concept of a “Golden Path” or “happy path” is **retired**.

There is **one authoritative path only**, enforced by governance and gates:

**PR → CI green → approved → merged → proof artifact**

Any alternative, shortcut, or implied happy path is invalid.

---

## Proof ≠ Publish (LOCKED)

These responsibilities are permanently separated:

* Proof → `green:*`, `ship`
* Publish artifacts → `handoff:commit` (PR lane only)
* Merge / release → humans + CI

Any script or workflow that mixes these roles is incorrect by definition.

---

## Definition of Done (DoD) (AUTHORITATIVE)

Work is not done until:

**PR opened → CI green → approved → merged**

No PR = work is not complete.

---

## Proof-Only Completion Rule (LOCKED)

If a DoD is met with no functional code changes, a Proof PR is still required.

It must include at least one of:

* committed proof artifact
* pgTAP or invariant assertion
* DEVLOG update with evidence

Required flow:
**Proof PR → CI → merge**

“No diff” = not closed.
Out-of-branch proof = invalid.

---

## Required Repo Scripts

The following scripts must exist and remain functional:

* `lint:migrations`
* `lint:sql`
* `lint:pgtap`
* `build`
* `handoff`
* `handoff:commit`
* `ship`

Roles:

* `handoff` → generate truth
* `handoff:commit` → publish (PR only)
* `ship` → verify only
* `green:*` → gate proofs

---

## DB Tests (pgTAP)

Authoritative runner: `npx supabase test db`

Rules:

* No alternative DB runners
* No local-only tests
* `auth.uid()` tests must set `request.jwt.claims` and use real `auth.users.id`

---

## Local Green Gate Loop (LOCKED)

Run in repo root.

One green pass consists of:

1. `npx supabase stop --no-backup`
2. `npx supabase start -x vector --ignore-health-check`
3. `npx supabase status`
4. `npm run lint:migrations`
5. `npm run lint:sql`
6. `npm run lint:pgtap`
7. `npm run build`

Requirements:

* Run twice consecutively
* No edits between runs

Failure rule:

* Stop at first failure
* Fix only that failure
* Restart from step 1

---

## CI Proof Requirements (LOCKED)

All PRs must pass:

* Migration lint
* SQL lint
* pgTAP
* Build
* Schema drift
* SECURITY DEFINER audit

### Definer Audit (Mandatory Gate)

All SECURITY DEFINER functions must:

* Use schema-qualified internal calls
* Use controlled `search_path`
* Contain no dynamic SQL

Failure = hard block.

---

## End-of-Session SOP (AUTHORITATIVE)

This replaces all previous publishing workflows.

### End-of-Session Trigger (LOCKED)

`handoff` and `handoff:commit` may be run ONLY:

1. At the end of the final working session of the day, OR
2. Immediately before closing a gate

They must NOT be run:

* mid-task
* between objectives
* during debugging
* as a partial checkpoint

Violations invalidate the snapshot.

---

### End Session Procedure

1. Verify clean tree (`git status`)
2. Generate truth artifacts (`npm run handoff`)
3. Publish via PR lane (`npm run handoff:commit`)
4. Open PR
5. Wait for CI green
6. Merge

No shortcuts.

---

## Gate Close Bundle (LOCKED)

After artifacts PR merge:

1. Checkout `main` and pull
2. Verify clean tree
3. Run `ship`
4. Record:

   * `MAIN_HEAD`
   * `HANDOFF_HEAD`
   * Migration parity
   * DEVLOG entry

Only then is the gate closed.

---

## Clean Tree Proof (Clarification)

`docs/handoff_latest.txt` is always dirty during generation.
Only `git status` on `main` after merge is authoritative.

---

## Release SOP (LOCKED)

Run only after merge and gate close.

On `main`:

* `git checkout main`
* `git pull`
* `git status`
* `npm run ship`

Failure = regression → New PR → Fix first failing gate only.

---

## Authority Reminder

If this SOP conflicts with behavior:

**Behavior is wrong.
Stop and realign.**

---

**QA note:** This change is wording-only.
**DoD:** docs-only PR + CI green.

## 2026-02-10 — Governance-change justification (2.15)
- If PR touches governance paths (docs/truth/**, .github/workflows/**, scripts/**, governance artifacts), PR MUST include: docs/governance/GOVERNANCE_CHANGE_PR<NNN>.md
- DEVLOG-only PRs are exempt.

---

## Proof Log HEAD Semantics (Clarified)

For proof logs that record `HEAD=`:

- `HEAD` denotes the **commit that was tested** (the code state the proof executed against).
- The proof file is committed **after** execution; therefore `HEAD` is expected to be an **ancestor** of the PR/merge commit that stores the proof artifact.
- Acceptance check:
  - `git merge-base --is-ancestor <HEAD> <MERGE_SHA>` must succeed.
  - `git diff --name-only <HEAD>..<MERGE_SHA>` must be proof-only (typically `docs/proofs/**`).

---

## Windows Operator Note (Token + Session Discipline)

On Windows, environment variables may not carry between shells (Git Bash vs PowerShell). For GitHub API proofs:

- Set and verify token in the **same session** that runs the proof.
- Verify via non-secret signal (length + short hash prefix) before running the proof.
- Prefer generating/writing proof logs via **PowerShell** (UTF-8 no BOM) to avoid shell redirection instability.


## 2026-02-10 — proof-commit-binding scope clarification
- proof-commit-binding is a PR gate; it validates proof binding **only when** docs/proofs/** changes exist in the PR; otherwise it emits PROOF_COMMIT_BINDING_SKIP and exits 0.

