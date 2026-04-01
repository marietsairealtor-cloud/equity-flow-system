What changed
Added public.list_user_tenants_v1() SECURITY DEFINER RPC returning
all tenants the authenticated user belongs to, with slug, role, and
is_current flag. Registered in execute_allowlist, definer_allowlist,
rpc_contract_registry. pgTAP tests added. Excluded from
7_8 catalog audit. ci_robot_owned_guard updated with proof log pattern.

Why safe
No new table. No privilege widening. RPC is authenticated-only.
Returns only tenants the caller is a member of via auth.uid().
No caller-supplied IDs. Fixed search_path. Standard envelope enforced.

Risk
Low. Read-only RPC. No writes. Tenant isolation enforced by
WHERE tm.user_id = auth.uid() join condition.

Rollback
DROP FUNCTION public.list_user_tenants_v1();
Revert truth file entries and test file changes.