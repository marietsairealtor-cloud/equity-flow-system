# Governance Change PR066 — 7.2 Gate Revision

## What changed
Build Route 7.2 gate declaration revised from `schema-drift + pgtap (merge-blocking)` to `pgtap (merge-blocking) + db-heavy (schema-drift stub until 8.0.2)`. No migration, schema, or enforcement logic changed.

## Why safe
The schema-drift gate is not currently implemented as a live required check. It is represented under the CI / db-heavy stub and is scheduled to convert to live execution at 8.0.2. Declaring schema-drift as an active merge-blocking gate in 7.2 created a contract mismatch between the Build Route specification, docs/truth/required_checks.json, and actual CI workflow jobs. This revision aligns the governance declaration with the current CI topology without weakening any enforcement or altering any privilege controls.

## Risk
None. This is a documentation correction only. No behavioral change. No migration change. No privilege change. Gate enforcement is unchanged — pgtap remains merge-blocking and schema-drift remains stubbed under db-heavy per deferred_proofs.json until 8.0.2.

## Rollback
Revert the Build Route line to prior wording via a single governance PR. No DB or CI changes required.
