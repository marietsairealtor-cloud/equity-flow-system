# GOVERNANCE CHANGE — 10.8.11I3 Pending Invites RPC Management Layer
UTC: 20260408T154613Z

## What changed
Added two new RPCs for pending invite management:
- list_pending_invites_v1: returns pending (unaccepted, unexpired) invites for
  current tenant; data.items is empty array when no invites; invited_by returns
  inviter email not raw UUID
- rescind_invite_v1(p_invite_id uuid): deletes pending invite; returns NOT_FOUND
  for accepted, expired, or cross-tenant invites; VALIDATION_ERROR for null input
Both RPCs are SECURITY DEFINER, admin+ only, tenant-scoped via current_tenant_id().
CONTRACTS.md section 46 added. Section 17 mapping table updated.
privilege_truth.json, execute_allowlist.json, definer_allowlist.json,
rpc_contract_registry.json, qa_scope_map.json, qa_claim.json,
ci_robot_owned_guard.ps1 all updated.

## Why safe
New RPCs only. No changes to existing invite flow or accept_pending_invites_v1.
No schema changes. No new columns. Admin+ role enforcement server-side via
require_min_role_v1. No caller-supplied tenant_id. Cross-tenant access denied
by design. rescind uses DELETE — no soft-delete ambiguity. Standard envelope.

## Risk
Low. Additive only. No existing RPC modified. No schema change. No privilege
change to existing RPCs. New RPCs are admin-gated — members cannot call them.
Worst case: rescind deletes wrong invite if invite_id is wrong — mitigated by
tenant scope check and UI confirmation requirement (10.8.11I4).

## Rollback
Revert this PR. Drop list_pending_invites_v1 and rescind_invite_v1 functions.
No data migrations. No schema rollback required. Existing invite flow unaffected.