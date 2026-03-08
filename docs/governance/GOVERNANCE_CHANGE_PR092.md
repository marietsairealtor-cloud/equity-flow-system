# Governance Change — PR092

## What changed
Created cloud migration parity guard for Build Route 8.3. Added docs/truth/cloud_migration_parity.json pinning cloud project ref and migration tip. Created scripts/cloud_migration_parity_check.ps1 (operator-run, lane-only). Updated truth bookkeeping files (qa_claim, qa_scope_map, robot-owned guard).

## Why safe
Lane-only gate — not merge-blocking. Operator-run only, no CI job. The guard is read-only against the cloud DB (SELECT on supabase_migrations.schema_migrations). No schema changes, no migrations, no security surface modified.

## Risk
None. Guard cannot modify any data. Fails only on mismatch between cloud and pinned truth. False positives possible if cloud is ahead of pinned tip (requires truth file update).

## Rollback
Remove cloud_migration_parity.json and cloud_migration_parity_check.ps1. Revert qa_claim, qa_scope_map, robot-owned guard. Single-commit revert.