# GOVERNANCE_CHANGE_PR059.md

## What changed
Added migration 20260302000000_6_11_role_guard_helper.sql introducing
public.require_min_role_v1(p_min tenant_role) as an internal non-executable
role guard helper. REVOKE EXECUTE on anon and authenticated co-located in
same migration. pgTAP tests added to enforce catalog presence and execute
denial for authenticated.

## Why safe
Function is internal only. REVOKE EXECUTE prevents any app role from calling
it directly. No new callable surface is exposed. No existing RLS policy,
privilege, or RPC is modified. Function will only be invoked by future
SECURITY DEFINER RPCs that already satisfy CONTRACTS.md S8.

## Risk
Low. Additive migration only. No table changes. No grant changes to existing
objects. REVOKE is idempotent on a fresh function.

## Rollback
DROP FUNCTION public.require_min_role_v1(public.tenant_role); — safe at any
point before any SD RPC depends on it.