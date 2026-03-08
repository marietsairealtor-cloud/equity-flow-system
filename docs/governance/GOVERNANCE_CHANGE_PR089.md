# Governance Change PR075 — 8.0.5 pgTAP + database-tests.yml Stub Conversion

## What changed
Converted db-heavy stub in ci.yml to live supabase test db execution.
database-tests.yml already existed with correct structure — no changes needed.
Added "database-tests / pgtap" to required_checks.json.
Cleared both deferred_proofs.json entries (db-heavy, database-tests.yml).
All pgTAP files audited against GUARDRAILS §25-28 — all pass.

## Why safe
The test suite has been running locally throughout development and passing.
Converting the stub to live CI execution does not change behavior — it makes
the existing passing tests merge-blocking. No migrations or schema changes.

## Risk
Low. If CI DB infrastructure is unavailable, the pgtap job will fail. This
is intentional — the stub was hiding this risk. The deliberate-failure proof
confirms the gate fails deterministically when tests fail.

## Rollback
Restore the db-heavy stub line in ci.yml, restore deferred_proofs.json entries,
remove "database-tests / pgtap" from required_checks.json via a single PR.
