-- 10.8.11I2: Corrective fix for get_workspace_settings_v1
-- Reads workspace_name, country, currency, measurement_unit from public.tenants
-- No schema changes. No new columns. RPC behavior fix only.

CREATE OR REPLACE FUNCTION public.get_workspace_settings_v1()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
  v_role public.tenant_role;
  v_slug text;
  v_name text;
  v_country text;
  v_currency text;
  v_measurement_unit text;
BEGIN
  v_tenant_id := public.current_tenant_id();

  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT tm.role
  INTO v_role
  FROM public.tenant_memberships tm
  WHERE tm.tenant_id = v_tenant_id
    AND tm.user_id = auth.uid();

  IF v_role IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Not a member of this tenant', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT ts.slug
  INTO v_slug
  FROM public.tenant_slugs ts
  WHERE ts.tenant_id = v_tenant_id
  LIMIT 1;

  SELECT t.name, t.country, t.currency, t.measurement_unit
  INTO v_name, v_country, v_currency, v_measurement_unit
  FROM public.tenants t
  WHERE t.id = v_tenant_id;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'tenant_id', v_tenant_id,
      'workspace_name', v_name,
      'slug', v_slug,
      'role', v_role,
      'country', v_country,
      'currency', v_currency,
      'measurement_unit', v_measurement_unit
    ),
    'error', null
  );
END;
$fn$;