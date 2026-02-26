# Governance Change — PR047

## What changed
Added pgTAP RLS structural audit test (Build Route 6.4). New test file rls_structural_audit.test.sql with 8 assertions rejecting forbidden permissive patterns on tenant-owned tables. Updated tenant_table_selector.json to v3 with tenant_owned_tables array distinguishing tenant-scoped tables from privilege-accessible tables. No CI topology changes. No new CI jobs. Gate is existing pgtap gate.

## Why safe
Additive test file only. No migrations, no schema changes, no RLS policy changes. Existing pgtap gate runs the new test automatically. tenant_table_selector.json update is backward-compatible (adds field, does not remove). All 21 tests pass (8 new + 13 existing).

## Risk
Low. Test-only change. No enforcement surface modified. No privilege or policy changes.

## Rollback
Revert the PR. Remove rls_structural_audit.test.sql. Restore tenant_table_selector.json to v2. No data or schema impact.
