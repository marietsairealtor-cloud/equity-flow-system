# GOVERNANCE CHANGE — 10.8.11E Workspace Settings Read RPC
UTC: 20260405T003126Z

## What changed
Added get_workspace_settings_v1 RPC via migration 20260403000002. Registered in
rpc_contract_registry.json, execute_allowlist.json, definer_allowlist.json,
privilege_truth.json. Added CONTRACTS.md §41 and §17 mapping row for this RPC.
pgTAP tests added covering auth success, correct slug, correct role, NOT_AUTHORIZED.

## Why safe
New additive RPC only. No existing RPCs modified. No schema surface changes beyond
the new function. SECURITY DEFINER with fixed search_path. anon cannot execute.
Tenant context derived from current_tenant_id() only. Membership validated server-side.
All registration files updated in same PR per SOP Phase 1 Step 4.

## Risk
Low. Additive only. No existing behavior changed. No table grants added.
No RLS changes. Returns only slug and role — no sensitive financial data exposed.
pgTAP tests pass covering all DoD scenarios including NOT_AUTHORIZED path.

## Rollback
Revert this PR. Run supabase db push to remove the function from cloud.
No data loss. No dependent RPCs in this PR. No WeWeb wiring in this PR.