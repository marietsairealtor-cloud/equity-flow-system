# SOP — Local Proof + CI Proof (WeWeb + Supabase)

## Purpose

Prevent regressions through repeatable proofs and strict role separation.

This SOP defines how work is proven locally, how truth artifacts are generated and published, how releases are verified, and what “done” means.

---

- Proof artifacts must be committed under `docs/proofs/` (never `logs/`).
- Any newly created proof file must pass `npm run fix:encoding` before commit.

## Core Principle (LOCKED)

### Proof ≠ Publish

These responsibilities are permanently separated:

* Proof → green:* , ship
* Publish artifacts → handoff:commit (PR lane only)
* Merge / release → humans + CI

Any script that mixes these roles is incorrect by definition.

---

## Definition of Done (DoD) (AUTHORITATIVE)

Work is not done until:

PR opened → CI green → approved → merged

No PR = work is not complete.

---

## Proof-Only Completion Rule (LOCKED)

If a DoD is met with no functional code changes, a Proof PR is still required.

It must include at least one of:

* committed proof artifact
* pgTAP or invariant assertion
* DEVLOG update with evidence

Required flow:

Proof PR → CI → merge

“No diff” = not closed.
Out-of-branch proof = invalid.

---

## Required Repo Scripts

The following scripts must exist and remain functional:

* lint:migrations
* lint:sql
* lint:pgtap
* build
* handoff
* handoff:commit
* ship

Roles:

handoff → generate truth
handoff:commit → publish (PR only)
ship → verify only
green:* → gate proofs

---

## DB Tests (pgTAP)

Authoritative runner: npx supabase test db

Rules:

* No alternative DB runners
* No local-only tests
* auth.uid() tests must set request.jwt.claims and use real auth.users.id

---

## Local Green Gate Loop (LOCKED)

Run in repo root.

One green pass consists of:

1. npx supabase stop --no-backup
2. npx supabase start -x vector --ignore-health-check
3. npx supabase status
4. npm run lint:migrations
5. npm run lint:sql
6. npm run lint:pgtap
7. npm run build

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
* Use controlled search_path
* Contain no dynamic SQL

Failure = hard block.

---

## End-of-Session SOP (AUTHORITATIVE)

This replaces all previous publishing workflows.

---

### End-of-Session Trigger (LOCKED)

handoff and handoff:commit may be run ONLY:

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

1. Verify clean tree (git status must be clean)
2. Generate truth artifacts (npm run handoff)
3. Publish via PR lane (npm run handoff:commit)
4. Open PR
5. Wait for CI green
6. Merge

No shortcuts.

---

## Gate Close Bundle (LOCKED)

After artifacts PR merge:

1. Checkout main and pull
2. Verify clean tree
3. Run ship
4. Record:

   * MAIN_HEAD
   * HANDOFF_HEAD
   * Migration parity
   * DEVLOG entry

Only then is the gate closed.

---

## Clean Tree Proof (Clarification)

docs/handoff_latest.txt is always dirty during generation.

Only git status on main after merge is authoritative.

---

## Release SOP (LOCKED)

Run only after merge and gate close.

On main:

* git checkout main
* git pull
* git status
* npm run ship

Failure = regression → New PR → Fix first failing gate only.

---

## Authority Reminder

If this SOP conflicts with behavior:

Behavior is wrong.
Stop and realign.

---
  Add/clarify: **proof artifacts must be committed under `docs/proofs/` (never `logs/`)** and **any newly created proof file must pass `fix:encoding` before commit**.


## Local Commit Gate (SQL Safety)

A pre-commit hook runs automatically on `git commit` and blocks committing unsafe SQL migrations.

- Trigger: `git commit` (automatic)
- Applies to: staged `supabase/**/*.sql`
- Runs: `node scripts/run_lint_sql.mjs` via `lint-staged`
- Outcome: unsafe SQL cannot be committed (prevents wasted CI cycles)

Notes:
- No manual action required by humans or AIs.
- Do not bypass with `--no-verify` unless emergency recovery; document any bypass.

