-- Migration: 10.8.8D -- Slug Ownership Check RPC
-- Adds check_slug_access_v1(p_slug text).
-- SECURITY DEFINER; authenticated-only; no caller-supplied tenant_id.
-- Returns slug_taken, is_owner_or_admin, and tenant_id only when caller is owner/admin.

DROP FUNCTION IF EXISTS public.check_slug_access_v1(text);

CREATE FUNCTION public.check_slug_access_v1(p_slug text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_user_id    uuid;
  v_tenant_id  uuid;
  v_role       public.tenant_role;
BEGIN
  -- Validate slug input first (testable without auth context)
  IF p_slug IS NULL OR length(trim(p_slug)) = 0 THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'p_slug is required.',
        'fields',  jsonb_build_object('p_slug', 'required')
      )
    );
  END IF;

  IF p_slug !~ '^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$' THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'Slug must be lowercase, URL-safe, and between 3 and 63 characters.',
        'fields',  jsonb_build_object('p_slug', 'invalid_format')
      )
    );
  END IF;

  -- Require authenticated context
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object('message', 'Authentication required.', 'fields', '{}'::jsonb)
    );
  END IF;

  -- Check if slug exists in tenant_slugs
  SELECT ts.tenant_id INTO v_tenant_id
  FROM public.tenant_slugs ts
  WHERE ts.slug = p_slug
  LIMIT 1;

  -- Slug does not exist
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok',    true,
      'code',  'OK',
      'data',  jsonb_build_object(
        'slug_taken',       false,
        'is_owner_or_admin', false,
        'tenant_id',        null
      ),
      'error', null
    );
  END IF;

  -- Slug exists -- check if current user is owner or admin of that tenant
  SELECT tm.role INTO v_role
  FROM public.tenant_memberships tm
  WHERE tm.tenant_id = v_tenant_id
    AND tm.user_id   = v_user_id
    AND tm.role IN ('owner', 'admin');
  
  IF v_role IS NOT NULL THEN
    -- Caller is owner or admin -- return tenant_id
    RETURN jsonb_build_object(
      'ok',    true,
      'code',  'OK',
      'data',  jsonb_build_object(
        'slug_taken',        true,
        'is_owner_or_admin', true,
        'tenant_id',         v_tenant_id
      ),
      'error', null
    );
  ELSE
    -- Slug taken by another tenant -- no tenant_id leak
    RETURN jsonb_build_object(
      'ok',    true,
      'code',  'OK',
      'data',  jsonb_build_object(
        'slug_taken',        true,
        'is_owner_or_admin', false,
        'tenant_id',         null
      ),
      'error', null
    );
  END IF;

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'ok',    false,
    'code',  'INTERNAL',
    'data',  '{}'::jsonb,
    'error', jsonb_build_object('message', SQLERRM, 'fields', '{}'::jsonb)
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.check_slug_access_v1(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_slug_access_v1(text) TO authenticated;