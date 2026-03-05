# Governance Change PR073 — 7.9 Tenant Context Integrity Invariant

## What changed
Added pgTAP test file supabase/tests/7_9_tenant_context_integrity.test.sql
with 12 tests proving: current_tenant_id() returns NULL without valid JWT claim;
all tenant-bound RPCs return NOT_AUTHORIZED when tenant context is NULL; cross-tenant
access fails under manipulated claim context; RPCs that accept p_tenant_id use it
for verification against JWT claim only (not trust bypass); catalog audit confirms
all tenant-bound RPCs reference current_tenant_id() internally.

## Why safe
Purely additive test suite. No migrations, schema, RPC, or policy changes.
All tests run inside ROLLBACK transaction — no persistent state.

## Risk
None. Read-only test addition. No behavioral change to any production code path.

## Rollback
Delete supabase/tests/7_9_tenant_context_integrity.test.sql via a single PR.
