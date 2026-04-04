# GOVERNANCE CHANGE — 10.8.11D Profile Settings RPC
UTC: 20260403T234918Z

## What changed
Added get_profile_settings_v1 RPC via migration 20260403000001. Registered in
rpc_contract_registry.json, execute_allowlist.json, definer_allowlist.json,
privilege_truth.json. Added CONTRACTS.md §40 and §17 mapping row for this RPC.

## Why safe
New additive RPC only. No existing RPCs modified. No schema surface changes beyond
the new function. SECURITY DEFINER with fixed search_path. anon cannot execute.
All registration files updated in same PR per SOP Phase 1 Step 4.

## Risk
Low. Additive only. No existing behavior changed. No table grants added.
No RLS changes. pgTAP tests pass covering auth success and NOT_AUTHORIZED path.

## Rollback
Revert this PR. Run supabase db push to remove the function from cloud.
No data loss. No dependent RPCs. No WeWeb wiring in this PR.