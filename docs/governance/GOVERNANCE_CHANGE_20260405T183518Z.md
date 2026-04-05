# GOVERNANCE CHANGE — 10.8.11F Workspace Settings General RPCs
UTC: 20260405T183518Z

## What changed
Added update_workspace_settings_v1 RPC via migration 20260405000001. Adds name,
country, currency, measurement_unit columns to public.tenants table. Registered in
rpc_contract_registry.json, execute_allowlist.json, definer_allowlist.json,
privilege_truth.json. Added CONTRACTS.md §42 and §17 mapping row. pgTAP tests
added covering admin success, member denied, slug conflict, blank field validation,
post-call state verification, and cross-tenant isolation.

## Why safe
New additive RPC and schema columns only. No existing RPCs modified. SECURITY
DEFINER with fixed search_path. require_min_role_v1('admin') enforced as first
executable statement. No caller-supplied tenant_id. Slug conflict handled without
tenant_id leak. All registration files updated in same PR per SOP Phase 1 Step 4.

## Risk
Low. New columns nullable with no constraints — no existing rows affected. No RLS
changes. No existing RPC signatures changed. pgTAP tests pass covering all DoD
scenarios including member denied and cross-tenant isolation.

## Rollback
Revert this PR. Run supabase db push to remove function from cloud. New columns
on tenants table are nullable — dropping them requires a separate corrective
migration. No data loss if columns are empty at time of rollback.