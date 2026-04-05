-- 20260405000001_10_8_11F_workspace_settings_general_rpcs.sql

ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS name text,
  ADD COLUMN IF NOT EXISTS country text,
  ADD COLUMN IF NOT EXISTS currency text,
  ADD COLUMN IF NOT EXISTS measurement_unit text;

DROP FUNCTION IF EXISTS public.update_workspace_settings_v1(text, text, text, text, text);

CREATE FUNCTION public.update_workspace_settings_v1(
  p_workspace_name text DEFAULT NULL,
  p_slug text DEFAULT NULL,
  p_country text DEFAULT NULL,
  p_currency text DEFAULT NULL,
  p_measurement_unit text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
BEGIN
  PERFORM public.require_min_role_v1('admin');

  v_tenant_id := public.current_tenant_id();

  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_workspace_name IS NOT NULL AND btrim(p_workspace_name) = '' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invalid workspace name', 'fields', jsonb_build_object('workspace_name', 'Must not be blank'))
    );
  END IF;

  IF p_country IS NOT NULL AND btrim(p_country) = '' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invalid country', 'fields', jsonb_build_object('country', 'Must not be blank'))
    );
  END IF;

  IF p_currency IS NOT NULL AND btrim(p_currency) = '' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invalid currency', 'fields', jsonb_build_object('currency', 'Must not be blank'))
    );
  END IF;

  IF p_measurement_unit IS NOT NULL AND btrim(p_measurement_unit) = '' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invalid measurement unit', 'fields', jsonb_build_object('measurement_unit', 'Must not be blank'))
    );
  END IF;

  IF p_slug IS NOT NULL THEN
    IF btrim(p_slug) = '' OR p_slug !~ '^[a-z0-9][a-z0-9\-]{1,48}[a-z0-9]$' THEN
      RETURN jsonb_build_object(
        'ok', false,
        'code', 'VALIDATION_ERROR',
        'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'Invalid slug format', 'fields', jsonb_build_object('slug', 'Must be lowercase, URL-safe, 3-50 characters'))
      );
    END IF;

    BEGIN
      INSERT INTO public.tenant_slugs (tenant_id, slug)
      VALUES (v_tenant_id, p_slug)
      ON CONFLICT (tenant_id) DO UPDATE SET slug = EXCLUDED.slug
      WHERE tenant_slugs.tenant_id = v_tenant_id;
    EXCEPTION WHEN unique_violation THEN
      RETURN jsonb_build_object(
        'ok', false,
        'code', 'CONFLICT',
        'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'Slug already taken', 'fields', jsonb_build_object('slug', 'Already in use'))
      );
    END;
  END IF;

  UPDATE public.tenants SET
    name = COALESCE(p_workspace_name, name),
    country = COALESCE(p_country, country),
    currency = COALESCE(p_currency, currency),
    measurement_unit = COALESCE(p_measurement_unit, measurement_unit)
  WHERE id = v_tenant_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_FOUND',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Workspace not found', 'fields', '{}'::jsonb)
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'tenant_id', v_tenant_id,
      'workspace_name', COALESCE(p_workspace_name, (SELECT name FROM public.tenants WHERE id = v_tenant_id)),
      'slug', COALESCE(p_slug, (SELECT slug FROM public.tenant_slugs WHERE tenant_id = v_tenant_id LIMIT 1)),
      'country', COALESCE(p_country, (SELECT country FROM public.tenants WHERE id = v_tenant_id)),
      'currency', COALESCE(p_currency, (SELECT currency FROM public.tenants WHERE id = v_tenant_id)),
      'measurement_unit', COALESCE(p_measurement_unit, (SELECT measurement_unit FROM public.tenants WHERE id = v_tenant_id))
    ),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.update_workspace_settings_v1(text, text, text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_workspace_settings_v1(text, text, text, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.update_workspace_settings_v1(text, text, text, text, text) TO authenticated;