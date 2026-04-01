DROP FUNCTION IF EXISTS public.list_user_tenants_v1();

CREATE OR REPLACE FUNCTION public.list_user_tenants_v1()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_user_id uuid;
  v_current_tenant_id uuid;
  v_items jsonb;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Not authorized', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT up.current_tenant_id INTO v_current_tenant_id
  FROM public.user_profiles up
  WHERE up.id = v_user_id;

  SELECT jsonb_agg(
    jsonb_build_object(
      'tenant_id', tm.tenant_id,
      'tenant_name', NULL,
      'slug', ts.slug,
      'role', tm.role,
      'is_current', (tm.tenant_id = v_current_tenant_id)
    )
    ORDER BY tm.created_at ASC
  ) INTO v_items
  FROM public.tenant_memberships tm
  LEFT JOIN public.tenant_slugs ts ON ts.tenant_id = tm.tenant_id
  WHERE tm.user_id = v_user_id;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object('items', COALESCE(v_items, '[]'::jsonb)),
    'error', NULL
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'ok', false,
    'code', 'INTERNAL',
    'data', '{}'::jsonb,
    'error', jsonb_build_object('message', SQLERRM, 'fields', '{}'::jsonb)
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.list_user_tenants_v1() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.list_user_tenants_v1() FROM anon;
GRANT EXECUTE ON FUNCTION public.list_user_tenants_v1() TO authenticated;