# Governance Change — PR068

## Build Route Item
7.4 Entitlement truth (plan/seat source of truth)

## What changed
Created get_user_entitlements_v1() RPC (SECURITY DEFINER) returning tenant membership state, role, and entitled boolean. Entitlement = active tenant_memberships row exists for user+tenant. Added migration 20260304000000_7_4_entitlement_truth.sql. Added pgTAP test (7_4_entitlement_truth.test.sql) covering member entitled, non-member not entitled, role correctness, and no-context NOT_AUTHORIZED. Created CI / entitlement-policy-coupling gate enforcing CONTRACTS.md must change when entitlement function changes. Updated execute_allowlist, definer_allowlist, required_checks, semantic contract, package.json, ci.yml, robot-owned guard, qa_claim, qa_scope_map.

## Why safe
RPC is SECURITY DEFINER with search_path locked to 'public'. Reads only tenant_memberships via current_tenant_id() + auth.uid() — no writes, STABLE. GRANT EXECUTE to authenticated only, REVOKE from anon. CI gate is structural (file-diff coupling check), no live DB needed. All existing tests remain passing.

## Risk
Low. auth.uid() returns NULL outside Supabase auth context — handled by NULL check returning NOT_AUTHORIZED. No plan/billing logic introduced (deferred per Build Route).

## Rollback
Drop migration. Remove from allowlists. Remove CI job. Revert package.json and ci.yml changes.
