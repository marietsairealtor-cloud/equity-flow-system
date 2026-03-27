## What changed
Added create_tenant_v1(p_idempotency_key text) SECURITY DEFINER RPC for workspace creation in onboarding (Build Route 10.8.8A). Updated CONTRACTS.md section 36 and RPC mapping table to govern new parameterized signature. Updated Build Route 10.8.8A DoD. Registered RPC in definer_allowlist.json, execute_allowlist.json, privilege_truth.json, rpc_contract_registry.json, qa_claim.json, and qa_scope_map.json. Added catalog audit exclusion for create_tenant_v1 in 7_8_role_enforcement_rpc.test.sql.

## Why safe
RPC is SECURITY DEFINER with fixed search_path = public. No caller-supplied tenant_id. Authentication enforced via auth.uid(). Idempotency is atomic via unique constraint on rpc_idempotency_log preventing duplicate workspace creation on retry. EXECUTE granted to authenticated only. anon cannot execute. No existing RPC signatures changed. No existing table grants widened. All truth files updated in same PR to maintain gate alignment.

## Risk
Low. Additive RPC only — no existing RPCs modified, no destructive schema changes, no privilege widening beyond authenticated EXECUTE on the new function. Idempotency key prevents duplicate workspace creation on concurrent or repeated calls. No frontend wiring in this PR so no user-facing impact until onboarding UI PR.

## Rollback
Execute DROP FUNCTION public.create_tenant_v1(text) and revert all truth file entries added in this PR: remove from definer_allowlist.json, execute_allowlist.json, privilege_truth.json, rpc_contract_registry.json, qa_claim.json, qa_scope_map.json. No data migration required. No existing functionality depends on this RPC until onboarding UI is wired in a subsequent PR.