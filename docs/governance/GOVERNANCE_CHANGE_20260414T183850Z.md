# GOVERNANCE CHANGE — 10.8.11O3 Archived Workspace Restore Targeting Corrective Fix
UTC: 20260414T183850Z

## What changed
- Migration 20260414000002_10_8_11O3_archived_workspace_restore_targeting.sql applied
- public.tenants.restore_token uuid DEFAULT NULL added
- Unique partial index: tenants_restore_token_unique ON tenants(restore_token) WHERE restore_token IS NOT NULL
- DROP FUNCTION public.restore_workspace_v1() -- O1 zero-parameter form removed
- process_workspace_retention_v1() updated: sets restore_token = gen_random_uuid() when archiving
- list_archived_workspaces_v1() added: returns archived workspaces owned by caller with restore_token and slug
- restore_workspace_v1(p_restore_token uuid) added: resolves token internally, verifies ownership and active subscription
- O1 test file updated: corrective compatibility test proving old signature gone, new signature exists
- O3 test file: 10 assertions covering full restore lifecycle
- CONTRACTS.md section 51 marked superseded, section 52 added, section 17 updated
- definer_allowlist.json, execute_allowlist.json, privilege_truth.json updated
- rpc_contract_registry.json updated
- ci_write_lock_coverage.ps1: restore_workspace_v1 approved exemption confirmed
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why this was needed
O1 restore_workspace_v1() relied on current_tenant_id() for restore targeting.
Archived workspaces are unreachable -- current_tenant_id() cannot resolve them.
O3 replaces the targeting mechanism with restore_token, a server-generated
UUID set only when a workspace is archived. Caller supplies the token; backend
resolves it to the real tenant internally. No tenant_id is ever caller-supplied.

## Why safe
- restore_token is not tenant_id -- does not violate tenancy audit rule
- Unique partial index enforces token uniqueness for non-null values
- Ownership verified server-side against resolved tenant
- Token is cleared on restore -- cannot be reused
- No schema changes to existing columns
- list_archived_workspaces_v1 is read-only, owner-scoped
- No WeWeb direct table access

## Risk
Low-medium. Hard to misuse because:
- token is opaque, not guessable (UUID)
- token is only valid while workspace is archived
- ownership check is server-side
- token is consumed on restore

## Rollback
Revert this PR. Run supabase db push to restore O1 function and remove O3 functions.
ALTER TABLE public.tenants DROP COLUMN restore_token;
No data migrations required.