## What changed
Added check_slug_access_v1(p_slug text) SECURITY DEFINER RPC (Build Route 10.8.8D). RPC checks whether a workspace slug is taken and whether the current authenticated user is owner or admin of that slug's tenant. Used by onboarding to prevent duplicate workspace creation and resume checkout for existing unpaid workspace. Updated CONTRACTS.md section 39 and mapping table. Registered in definer_allowlist.json, execute_allowlist.json, privilege_truth.json, rpc_contract_registry.json, qa_claim.json, qa_scope_map.json, ci_robot_owned_guard.ps1.

## Why safe
RPC is SECURITY DEFINER with fixed search_path = public. No caller-supplied tenant_id. tenant_id returned only when caller is confirmed owner or admin of that slug's tenant via tenant_memberships. No tenant_id leak when caller is not owner or admin. EXECUTE granted to authenticated only. anon cannot execute. No existing RPC signatures changed. No schema destructive changes.

## Risk
Low. Additive RPC only. No existing RPCs modified. No privilege widening. No schema changes beyond new function. Slug enumeration risk mitigated -- RPC returns only boolean slug_taken when caller is not owner or admin, no tenant identity exposed.

## Rollback
Execute DROP FUNCTION public.check_slug_access_v1(text) and revert all truth file entries added in this PR. No data migration required. No existing functionality depends on this RPC until onboarding UI is wired in a subsequent PR.