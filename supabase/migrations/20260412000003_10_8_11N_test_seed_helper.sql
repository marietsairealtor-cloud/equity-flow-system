-- Test seed helper: create_active_workspace_seed_v1()
-- Seeds a tenant, auth user, membership, user profile, and active subscription
-- for use in pgTAP test files. Not for production use.
-- Call as superuser before SET ROLE authenticated.

CREATE OR REPLACE FUNCTION public.create_active_workspace_seed_v1(
  p_seed_workspace uuid,
  p_user_id        uuid,
  p_role           public.tenant_role DEFAULT 'admin'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  INSERT INTO public.tenants (id)
  VALUES (p_seed_workspace)
  ON CONFLICT DO NOTHING;

  INSERT INTO auth.users (id, email, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
  VALUES (p_user_id, 'seed_' || p_user_id || '@test.local', now(), now(), '{}', '{}', 'authenticated', 'authenticated')
  ON CONFLICT DO NOTHING;

  INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
  VALUES (gen_random_uuid(), p_seed_workspace, p_user_id, p_role)
  ON CONFLICT (tenant_id, user_id) DO NOTHING;

  INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
  VALUES (p_seed_workspace, 'active', now() + interval '1 year')
  ON CONFLICT DO NOTHING;

  INSERT INTO public.user_profiles (id, current_tenant_id)
  VALUES (p_user_id, p_seed_workspace)
  ON CONFLICT DO NOTHING;
END;
$fn$;

REVOKE ALL ON FUNCTION public.create_active_workspace_seed_v1(uuid, uuid, public.tenant_role) FROM PUBLIC;