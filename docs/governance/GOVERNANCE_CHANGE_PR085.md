# Governance Change — PR085

## What changed
Added new CI job `schema-drift` to `.github/workflows/ci.yml` that dumps schema from a live CI DB (post migration replay) and diffs it byte-for-byte against `generated/schema.sql`. Job added to `required.needs` making it merge-blocking. Updated `deferred_proofs.json` to remove schema-drift from the db-heavy umbrella stub. Added supabase pg_dump patterns to ci_semantic_contract.mjs allowlist if needed.

## Why safe
This converts an existing stub gate to live execution. No new security surface is introduced. The schema-drift check is a read-only comparison that cannot modify the database. The db-heavy umbrella entry is narrowed to reflect remaining stubs only. No other stub gates are converted in this PR.

## Risk
Low. Job may fail if pg_dump output format differs from the committed `generated/schema.sql` due to Postgres version or dump ordering differences. This would block PRs but is diagnosable from the diff output. No security surface is weakened.

## Rollback
Revert the `schema-drift` job addition in ci.yml, restore the db-heavy umbrella entry in deferred_proofs.json to include schema-drift, remove `schema-drift` from `required.needs`. Run `npm run truth:sync`. Single-commit revert.