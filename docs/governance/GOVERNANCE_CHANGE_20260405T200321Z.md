# GOVERNANCE CHANGE — 10.8.11G Workspace Members RPCs
UTC: 20260405T200321Z

## What changed
Added four RPCs via migration 20260405000002: list_workspace_members_v1,
invite_workspace_member_v1, update_member_role_v1, remove_member_v1.
Added display_name column to public.user_profiles. Registered all four RPCs
in rpc_contract_registry.json, execute_allowlist.json, definer_allowlist.json,
privilege_truth.json. Added CONTRACTS.md §43 and four §17 mapping rows.
pgTAP tests added: 22 tests covering all DoD scenarios.

## Why safe
All four RPCs are SECURITY DEFINER with fixed search_path = public. No
caller-supplied tenant_id. Role enforcement via require_min_role_v1 on all
mutation RPCs. list RPC enforces minimum member role. display_name column
is nullable text — no existing rows affected. All registration files updated
in same PR per SOP Phase 1 Step 4.

## Risk
Low. Additive only. No existing RPCs modified. No RLS changes. No existing
RPC signatures changed. display_name column nullable — safe to add. pgTAP
tests pass covering member denial, cross-tenant isolation, duplicate invite
rejection, and post-call state verification.

## Rollback
Revert this PR. Run supabase db push to remove functions from cloud.
display_name column is nullable — dropping requires a separate corrective
migration if data exists. No data loss if column is empty at rollback time.