-- Migration: 10.8.8B -- Set Workspace Slug RPC
-- Adds UNIQUE(tenant_id) to tenant_slugs and creates set_tenant_slug_v1(p_slug text).
-- SECURITY DEFINER; authenticated-only; min role owner/admin; no caller-supplied tenant_id.

ALTER TABLE public.tenant_slugs
  DROP CONSTRAINT IF EXISTS tenant_slugs_tenant_id_unique;

ALTER TABLE public.tenant_slugs
  ADD CONSTRAINT tenant_slugs_tenant_id_unique UNIQUE (tenant_id);

DROP FUNCTION IF EXISTS public.set_tenant_slug_v1(text);

CREATE FUNCTION public.set_tenant_slug_v1(p_slug text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
BEGIN
  -- Role guard must be first executable statement per CONTRACTS §9
  PERFORM public.require_min_role_v1('admin'::public.tenant_role);

  -- Validate slug input
  IF p_slug IS NULL OR length(trim(p_slug)) = 0 THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_slug is required.', 'fields', jsonb_build_object('p_slug', 'required'))
    );
  END IF;

  -- Validate slug format: lowercase, URL-safe, matches existing CHECK constraint
  IF p_slug !~ '^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$' THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object('message', 'Slug must be lowercase, URL-safe, and between 3 and 63 characters.', 'fields', jsonb_build_object('p_slug', 'invalid_format'))
    );
  END IF;

  -- Require authenticated context
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object('message', 'Authentication required.', 'fields', '{}'::jsonb)
    );
  END IF;

  -- Resolve tenant context
  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object('message', 'No active tenant context.', 'fields', '{}'::jsonb)
    );
  END IF;

  -- Upsert slug: one slug per tenant enforced by UNIQUE(tenant_id)
  INSERT INTO public.tenant_slugs (tenant_id, slug)
  VALUES (v_tenant_id, p_slug)
  ON CONFLICT (tenant_id) DO UPDATE
    SET slug = EXCLUDED.slug;

  RETURN jsonb_build_object(
    'ok',    true,
    'code',  'OK',
    'data',  jsonb_build_object('tenant_id', v_tenant_id, 'slug', p_slug),
    'error', null
  );

EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'CONFLICT',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object('message', 'Slug is already taken.', 'fields', jsonb_build_object('p_slug', 'taken'))
    );
  WHEN raise_exception THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object('message', SQLERRM, 'fields', '{}'::jsonb)
    );
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'INTERNAL',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object('message', SQLERRM, 'fields', '{}'::jsonb)
    );
END;
$fn$;

REVOKE ALL ON FUNCTION public.set_tenant_slug_v1(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_tenant_slug_v1(text) TO authenticated;