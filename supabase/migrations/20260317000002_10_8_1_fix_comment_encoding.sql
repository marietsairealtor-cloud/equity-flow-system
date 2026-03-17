-- 20260317000002_10_8_1_fix_comment_encoding.sql
-- Fix: replace em dash with ASCII -- in resolve_form_slug_v1 comment
-- Internal comment change only -- interface identical (no DROP required per CONTRACTS §2)

CREATE OR REPLACE FUNCTION public.resolve_form_slug_v1(
  p_slug      text,
  p_form_type text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
  v_valid_types text[] := ARRAY['buyer', 'seller', 'birddog'];
BEGIN
  -- Validate form_type -- NOT_FOUND (no form type leak)
  IF p_form_type IS NULL OR NOT (p_form_type = ANY(v_valid_types)) THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Not found', 'fields', '{}'::json)
    );
  END IF;

  -- Validate slug format
  IF p_slug IS NULL OR p_slug !~ '^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Not found', 'fields', '{}'::json)
    );
  END IF;

  -- Resolve slug to tenant_id
  SELECT ts.tenant_id INTO v_tenant_id
  FROM public.tenant_slugs ts
  WHERE ts.slug = p_slug;

  IF v_tenant_id IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Not found', 'fields', '{}'::json)
    );
  END IF;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('tenant_id', v_tenant_id),
    'error', null
  );
END;
$fn$;