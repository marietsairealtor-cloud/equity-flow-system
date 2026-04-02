What changed
Added public.set_current_tenant_v1(p_tenant_id uuid) SECURITY DEFINER
RPC to explicitly switch the current workspace by upserting
user_profiles.current_tenant_id. Validates caller is a member of the
target tenant. Registered in all required truth files.

Why safe
No privilege widening. Authenticated-only. Membership validated
server-side before any update. Upsert pattern prevents silent no-op.
No caller-supplied user_id.

Risk
Low. Write is scoped to caller's own user_profiles row only.

Rollback
DROP FUNCTION public.set_current_tenant_v1(uuid);
Revert truth file entries and test file changes.