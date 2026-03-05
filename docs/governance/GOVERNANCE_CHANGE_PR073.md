# Governance Change PR073 — 7.9 Tenant Context Integrity Invariant

## What changed
Removed p_tenant_id caller input from foundation_log_activity_v1 and
lookup_share_token_v1 RPCs (migration 20260305000000). Tenant ID is now
derived strictly from JWT via current_tenant_id() — no RPC accepts tenant_id
as caller input. Added pgTAP test file 7_9_tenant_context_integrity.test.sql
with 12 tests. Updated 6_9_foundation_surface.test.sql, 7_5_rls_negative_suite.test.sql,
and share_link_isolation.test.sql to match new signatures.

## Why safe
Removing p_tenant_id tightens security — tenant context can no longer be
supplied by caller. All tenant binding now derives exclusively from JWT claim.
The cross-tenant mismatch check previously done via p_tenant_id vs
current_tenant_id() is now implicit — the query simply finds no rows for the
wrong tenant. All existing tests updated and passing.

## Risk
Low. RPC signature change is breaking for any caller passing p_tenant_id.
All known callers are in the test suite and have been updated. No production
traffic exists yet.

## Rollback
Revert migration 20260305000000 to restore p_tenant_id params. Update tests
to restore old call signatures.
