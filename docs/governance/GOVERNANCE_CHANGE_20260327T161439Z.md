## What changed
Added set_tenant_slug_v1(p_slug text) SECURITY DEFINER RPC for workspace slug management in onboarding Step 2 (Build Route 10.8.8B). Added UNIQUE(tenant_id) constraint to public.tenant_slugs enforcing one slug per tenant at schema level. Updated CONTRACTS.md section 37 and RPC mapping table. Updated Build Route 10.8.8B DoD. Registered RPC in definer_allowlist.json, execute_allowlist.json, privilege_truth.json, rpc_contract_registry.json, qa_claim.json, qa_scope_map.json, ci_robot_owned_guard.ps1.

## Why safe
RPC is SECURITY DEFINER with fixed search_path = public. No caller-supplied tenant_id. Tenant context derived from current_tenant_id() only. Role guard require_min_role_v1(admin) is first executable statement per CONTRACTS §9. Slug validated server-side against existing CHECK constraint pattern. UNIQUE(tenant_id) constraint is additive and non-destructive. EXECUTE granted to authenticated only. anon cannot execute. No existing RPC signatures changed. No existing table grants widened.

## Risk
Low. Additive RPC and additive constraint only. UNIQUE(tenant_id) constraint could fail if existing data has duplicate tenant_id rows in tenant_slugs — verified absent before migration applied. Slug collision returns CONFLICT envelope, not unhandled exception. No frontend wiring in this PR so no user-facing impact until onboarding UI PR.

## Rollback
Execute DROP FUNCTION public.set_tenant_slug_v1(text) and ALTER TABLE public.tenant_slugs DROP CONSTRAINT tenant_slugs_tenant_id_unique. Revert all truth file entries added in this PR. No data migration required. No existing functionality depends on this RPC until onboarding UI is wired in a subsequent PR.