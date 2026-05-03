-- 10.12A: Intake Backend -- Submission Persistence
-- Creates intake_submissions and intake_buyers tables.
-- Adds list_intake_submissions_v1 and list_buyers_v1 RPCs.
-- Drops + recreates submit_form_v1(p_slug, p_form_type, p_payload) to also
-- persist to intake_submissions. All existing logic preserved.

-- ============================================================
-- TABLE: intake_submissions
-- ============================================================
CREATE TABLE public.intake_submissions (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid        NOT NULL REFERENCES public.tenants(id),
  form_type       text        NOT NULL CHECK (form_type IN ('seller', 'buyer', 'birddog')),
  payload         jsonb       NOT NULL DEFAULT '{}'::jsonb,
  source          text        NOT NULL DEFAULT 'web',
  submitted_at    timestamptz NOT NULL DEFAULT now(),
  reviewed_at     timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

REVOKE ALL ON public.intake_submissions FROM anon, authenticated;

ALTER TABLE public.intake_submissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY intake_submissions_tenant_isolation
  ON public.intake_submissions
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

CREATE INDEX intake_submissions_tenant_submitted_idx
  ON public.intake_submissions (tenant_id, submitted_at DESC, id DESC);

-- ============================================================
-- TABLE: intake_buyers
-- ============================================================
CREATE TABLE public.intake_buyers (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           uuid        NOT NULL REFERENCES public.tenants(id),
  name                text,
  email               text,
  phone               text,
  areas_of_interest   text,
  budget_range        text,
  deal_type_tags      text[],
  price_range_notes   text,
  notes               text,
  is_active           boolean     NOT NULL DEFAULT true,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

REVOKE ALL ON public.intake_buyers FROM anon, authenticated;

ALTER TABLE public.intake_buyers ENABLE ROW LEVEL SECURITY;

CREATE POLICY intake_buyers_tenant_isolation
  ON public.intake_buyers
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

CREATE INDEX intake_buyers_tenant_created_idx
  ON public.intake_buyers (tenant_id, created_at DESC, id DESC);

-- ============================================================
-- RPC: submit_form_v1 (DROP + recreate -- adds intake_submissions write)
-- Preserves all 10.8.11N logic: slug validation, spam token,
-- subscription block, draft_deals insert, seller MAO pre-fill.
-- New: also writes to intake_submissions on every successful submission.
-- ============================================================
DROP FUNCTION IF EXISTS public.submit_form_v1(text, text, jsonb);

CREATE FUNCTION public.submit_form_v1(
  p_slug      text,
  p_form_type text,
  p_payload   jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id    uuid;
  v_draft_id     uuid;
  v_intake_id    uuid;
  v_asking_price numeric;
  v_repair_est   numeric;
  v_valid_types  text[] := ARRAY['buyer', 'seller', 'birddog'];
  v_spam_token   text;
  v_sub_status   text;
  v_period_end   timestamptz;
BEGIN
  -- Validate form_type
  IF p_form_type IS NULL OR NOT (p_form_type = ANY(v_valid_types)) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invalid form type',
        'fields', jsonb_build_object('form_type', 'Must be buyer, seller, or birddog')));
  END IF;

  -- Validate slug
  IF p_slug IS NULL OR p_slug !~ '^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Not found', 'fields', '{}'::jsonb));
  END IF;

  -- Validate payload present
  IF p_payload IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Payload required',
        'fields', jsonb_build_object('payload', 'Required')));
  END IF;

  -- Validate spam token present
  v_spam_token := p_payload->>'spam_token';
  IF v_spam_token IS NULL OR length(trim(v_spam_token)) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Spam protection token required',
        'fields', jsonb_build_object('spam_token', 'Required')));
  END IF;

  -- Resolve slug to tenant
  SELECT ts.tenant_id INTO v_tenant_id
  FROM public.tenant_slugs ts
  WHERE ts.slug = p_slug;

  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Not found', 'fields', '{}'::jsonb));
  END IF;

  -- Block submissions for expired workspaces (deterministic: latest row only)
  SELECT ts.status, ts.current_period_end
  INTO v_sub_status, v_period_end
  FROM public.tenant_subscriptions ts
  WHERE ts.tenant_id = v_tenant_id
  ORDER BY ts.created_at DESC
  LIMIT 1;

  IF v_sub_status IS NULL OR v_sub_status = 'canceled' OR v_period_end <= now() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'This workspace is not accepting submissions.',
        'fields', '{}'::jsonb));
  END IF;

  -- Extract MAO pre-fill fields from seller submissions (safe cast via NULLIF)
  IF p_form_type = 'seller' THEN
    v_asking_price := NULLIF(p_payload->>'asking_price', '')::numeric;
    v_repair_est   := NULLIF(p_payload->>'repair_estimate', '')::numeric;
  END IF;

  -- Insert draft deal record (existing behaviour)
  INSERT INTO public.draft_deals (tenant_id, slug, form_type, payload, asking_price, repair_estimate)
  VALUES (v_tenant_id, p_slug, p_form_type, p_payload, v_asking_price, v_repair_est)
  RETURNING id INTO v_draft_id;

  -- Persist intake record (10.12A)
  INSERT INTO public.intake_submissions (tenant_id, form_type, payload, source)
  VALUES (v_tenant_id, p_form_type, p_payload, 'web')
  RETURNING id INTO v_intake_id;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK',
    'data', jsonb_build_object('draft_id', v_draft_id, 'intake_id', v_intake_id),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.submit_form_v1(text, text, jsonb) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.submit_form_v1(text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_form_v1(text, text, jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.submit_form_v1(text, text, jsonb) TO authenticated;

-- ============================================================
-- RPC: list_intake_submissions_v1
-- ============================================================
CREATE FUNCTION public.list_intake_submissions_v1(
  p_limit int DEFAULT 25
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
  v_limit     int;
  v_items     jsonb;
BEGIN
  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context.', 'fields', '{}'::jsonb)
    );
  END IF;

  v_limit := COALESCE(p_limit, 25);
  IF v_limit < 1 OR v_limit > 100 THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_limit must be between 1 and 100.',
        'fields', jsonb_build_object('p_limit', 'Out of range.'))
    );
  END IF;

  SELECT jsonb_agg(r)
  INTO v_items
  FROM (
    SELECT jsonb_build_object(
      'id',           id,
      'form_type',    form_type,
      'payload',      payload,
      'source',       source,
      'submitted_at', submitted_at,
      'reviewed_at',  reviewed_at
    ) AS r
    FROM public.intake_submissions
    WHERE tenant_id = v_tenant_id
    ORDER BY submitted_at DESC, id DESC
    LIMIT v_limit
  ) sub;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK',
    'data', jsonb_build_object('items', COALESCE(v_items, '[]'::jsonb)),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.list_intake_submissions_v1(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_intake_submissions_v1(int) TO authenticated;

-- ============================================================
-- RPC: list_buyers_v1
-- ============================================================
CREATE FUNCTION public.list_buyers_v1(
  p_limit int DEFAULT 25
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
  v_limit     int;
  v_items     jsonb;
BEGIN
  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context.', 'fields', '{}'::jsonb)
    );
  END IF;

  v_limit := COALESCE(p_limit, 25);
  IF v_limit < 1 OR v_limit > 100 THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_limit must be between 1 and 100.',
        'fields', jsonb_build_object('p_limit', 'Out of range.'))
    );
  END IF;

  SELECT jsonb_agg(r)
  INTO v_items
  FROM (
    SELECT jsonb_build_object(
      'id',                id,
      'name',              name,
      'email',             email,
      'phone',             phone,
      'areas_of_interest', areas_of_interest,
      'budget_range',      budget_range,
      'deal_type_tags',    deal_type_tags,
      'price_range_notes', price_range_notes,
      'notes',             notes,
      'is_active',         is_active,
      'created_at',        created_at,
      'updated_at',        updated_at
    ) AS r
    FROM public.intake_buyers
    WHERE tenant_id = v_tenant_id
    ORDER BY created_at DESC, id DESC
    LIMIT v_limit
  ) sub;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK',
    'data', jsonb_build_object('items', COALESCE(v_items, '[]'::jsonb)),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.list_buyers_v1(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_buyers_v1(int) TO authenticated;