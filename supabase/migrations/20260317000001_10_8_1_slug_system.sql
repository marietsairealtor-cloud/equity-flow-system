-- 20260317000001_10_8_1_slug_system.sql
-- Build Route 10.8.1: Slug System (Forms Infrastructure)
-- tenant_slugs table, resolve_form_slug_v1, submit_form_v1

-- ============================================================
-- 1) tenant_slugs table
-- ============================================================

CREATE TABLE public.tenant_slugs (
  id              uuid        NOT NULL DEFAULT gen_random_uuid(),
  tenant_id       uuid        NOT NULL,
  slug            text        NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tenant_slugs_pkey PRIMARY KEY (id),
  CONSTRAINT tenant_slugs_slug_unique UNIQUE (slug),
  CONSTRAINT tenant_slugs_tenant_id_fkey FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id) ON DELETE CASCADE,
  CONSTRAINT tenant_slugs_slug_format CHECK (slug ~ '^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$')
);

-- RLS ON — default deny
ALTER TABLE public.tenant_slugs ENABLE ROW LEVEL SECURITY;

-- No direct access — all reads via allowlisted RPCs
REVOKE ALL ON TABLE public.tenant_slugs FROM anon, authenticated;

-- ============================================================
-- 2) draft_deals table (for submit_form_v1 pre-fill)
-- ============================================================

CREATE TABLE public.draft_deals (
  id              uuid        NOT NULL DEFAULT gen_random_uuid(),
  tenant_id       uuid        NOT NULL,
  slug            text        NOT NULL,
  form_type       text        NOT NULL,
  payload         jsonb       NOT NULL DEFAULT '{}'::jsonb,
  asking_price    numeric,
  repair_estimate numeric,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT draft_deals_pkey PRIMARY KEY (id),
  CONSTRAINT draft_deals_tenant_id_fkey FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id) ON DELETE CASCADE,
  CONSTRAINT draft_deals_form_type_check CHECK (form_type IN ('buyer', 'seller', 'birddog'))
);

ALTER TABLE public.draft_deals ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.draft_deals FROM anon, authenticated;

-- ============================================================
-- 3) resolve_form_slug_v1 — anon-callable, SECURITY DEFINER
-- ============================================================
-- CONTRACTS §12 controlled exception: anon EXECUTE granted.
-- Rationale: Public intake form URLs require slug resolution without auth.
-- Security: Returns only tenant_id — no internal identifiers exposed.
-- No existence leak between form types: invalid slug OR form_type → NOT_FOUND.

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
  -- Validate form_type — NOT_FOUND (no form type leak)
  IF p_form_type IS NULL OR NOT (p_form_type = ANY(v_valid_types)) THEN
    RETURN json_build_object(
      'ok', false,
      'code', 'NOT_FOUND',
      'data', null,
      'error', json_build_object('message', 'Not found', 'fields', '{}'::json)
    );
  END IF;

  -- Validate slug format
  IF p_slug IS NULL OR p_slug !~ '^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$' THEN
    RETURN json_build_object(
      'ok', false,
      'code', 'NOT_FOUND',
      'data', null,
      'error', json_build_object('message', 'Not found', 'fields', '{}'::json)
    );
  END IF;

  -- Resolve slug to tenant_id
  SELECT ts.tenant_id INTO v_tenant_id
  FROM public.tenant_slugs ts
  WHERE ts.slug = p_slug;

  IF v_tenant_id IS NULL THEN
    RETURN json_build_object(
      'ok', false,
      'code', 'NOT_FOUND',
      'data', null,
      'error', json_build_object('message', 'Not found', 'fields', '{}'::json)
    );
  END IF;

  RETURN json_build_object(
    'ok', true,
    'code', 'OK',
    'data', json_build_object('tenant_id', v_tenant_id),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.resolve_form_slug_v1(text, text) OWNER TO postgres;

-- CONTRACTS §12 controlled exception — anon EXECUTE
REVOKE ALL ON FUNCTION public.resolve_form_slug_v1(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_form_slug_v1(text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.resolve_form_slug_v1(text, text) TO authenticated;

-- ============================================================
-- 4) submit_form_v1 — anon-callable, SECURITY DEFINER
-- ============================================================
-- CONTRACTS §12 controlled exception: anon EXECUTE granted.
-- Rationale: Public intake form submissions require no auth.
-- Security: Resolves tenant from slug internally — no tenant_id param.
-- Seller submissions create draft deal with asking_price + repair_estimate.

CREATE OR REPLACE FUNCTION public.submit_form_v1(
  p_slug       text,
  p_form_type  text,
  p_payload    jsonb
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id     uuid;
  v_draft_id      uuid;
  v_asking_price  numeric;
  v_repair_est    numeric;
  v_valid_types   text[] := ARRAY['buyer', 'seller', 'birddog'];
  v_spam_token    text;
BEGIN
  -- Validate form_type
  IF p_form_type IS NULL OR NOT (p_form_type = ANY(v_valid_types)) THEN
    RETURN json_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', null,
      'error', json_build_object(
        'message', 'Invalid form type',
        'fields', json_build_object('form_type', 'Must be buyer, seller, or birddog')
      )
    );
  END IF;

  -- Validate slug
  IF p_slug IS NULL OR p_slug !~ '^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$' THEN
    RETURN json_build_object(
      'ok', false,
      'code', 'NOT_FOUND',
      'data', null,
      'error', json_build_object('message', 'Not found', 'fields', '{}'::json)
    );
  END IF;

  -- Validate payload present
  IF p_payload IS NULL THEN
    RETURN json_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', null,
      'error', json_build_object(
        'message', 'Payload required',
        'fields', json_build_object('payload', 'Required')
      )
    );
  END IF;

  -- Validate spam token present (Turnstile/reCAPTCHA)
  v_spam_token := p_payload->>'spam_token';
  IF v_spam_token IS NULL OR length(trim(v_spam_token)) = 0 THEN
    RETURN json_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', null,
      'error', json_build_object(
        'message', 'Spam protection token required',
        'fields', json_build_object('spam_token', 'Required')
      )
    );
  END IF;

  -- Resolve slug to tenant
  SELECT ts.tenant_id INTO v_tenant_id
  FROM public.tenant_slugs ts
  WHERE ts.slug = p_slug;

  IF v_tenant_id IS NULL THEN
    RETURN json_build_object(
      'ok', false,
      'code', 'NOT_FOUND',
      'data', null,
      'error', json_build_object('message', 'Not found', 'fields', '{}'::json)
    );
  END IF;

  -- Extract MAO pre-fill fields from seller submissions
  IF p_form_type = 'seller' THEN
    v_asking_price := (p_payload->>'asking_price')::numeric;
    v_repair_est   := (p_payload->>'repair_estimate')::numeric;
  END IF;

  -- Insert draft deal record
  INSERT INTO public.draft_deals (
    tenant_id,
    slug,
    form_type,
    payload,
    asking_price,
    repair_estimate
  ) VALUES (
    v_tenant_id,
    p_slug,
    p_form_type,
    p_payload,
    v_asking_price,
    v_repair_est
  )
  RETURNING id INTO v_draft_id;

  RETURN json_build_object(
    'ok', true,
    'code', 'OK',
    'data', json_build_object('draft_id', v_draft_id),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.submit_form_v1(text, text, jsonb) OWNER TO postgres;

-- CONTRACTS §12 controlled exception — anon EXECUTE
REVOKE ALL ON FUNCTION public.submit_form_v1(text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_form_v1(text, text, jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.submit_form_v1(text, text, jsonb) TO authenticated;
