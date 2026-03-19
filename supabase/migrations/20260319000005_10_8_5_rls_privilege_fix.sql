-- 10.8.5 RLS privilege fix: restore EXECUTE on current_tenant_id() to authenticated.
-- Item 10.8.3B REVOKE FROM PUBLIC was overly broad -- it broke RLS evaluation for
-- deal_tc and deal_tc_checklist (and potentially any future tenant-scoped table).
-- QA ruling 2026-03-19: narrow GRANT to authenticated only per Option 1.
-- CONTRACTS.md s12 updated to document this exception.

GRANT EXECUTE ON FUNCTION public.current_tenant_id() TO authenticated;