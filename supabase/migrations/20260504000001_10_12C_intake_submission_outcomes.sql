-- 10.12C: Intake Backend -- Submission Outcomes + MAO Pre-fill
-- Adds address column to draft_deals.
-- Drops + recreates submit_form_v1: seller stores address only (no pricing),
-- buyer calls upsert_buyer_from_intake_v1, birddog unchanged.
-- New RPC: upsert_buyer_from_intake_v1 with deterministic dedupe.

-- ============================================================
-- ALTER: draft_deals -- add address column
-- ============================================================
ALTER TABLE public.draft_deals
  ADD COLUMN IF NOT EXISTS address text;

-- ============================================================
-- RPC: upsert_buyer_from_intake_v1
-- Internal helper only -- called by submit_form_v1 on buyer submissions.
-- Not externally callable (REVOKE ALL from PUBLIC, anon, authenticated).
-- Exempt from role enforcement and write-lock helper:
--   Called only from anon-capable submit_form_v1 after slug tenant
--   resolution and subscription gate. Tenant passed explicitly.
--   No external EXECUTE grants exist.
-- Dedupe rule:
--   1. Exact email match first (lower-normalized, only when email present)
--   2. Phone fallback ONLY when submission email is absent
--   3. Email present + no email match = new record (no phone merge)
-- ============================================================
CREATE FUNCTION public.upsert_buyer_from_intake_v1(
  p_resolved_tenant uuid,
  p_payload   jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_buyer_id        uuid;
  v_email           text;
  v_phone           text;
  v_name            text;
  v_deal_type_tags  text[];
BEGIN
  v_email := NULLIF(trim(p_payload->>'email'), '');
  v_phone := NULLIF(trim(p_payload->>'phone'), '');
  v_name  := NULLIF(trim(p_payload->>'name'),  '');

  -- Safe deal_type_tags parsing -- only when payload key is a JSON array
  IF p_payload ? 'deal_type_tags' AND jsonb_typeof(p_payload->'deal_type_tags') = 'array' THEN
    v_deal_type_tags := ARRAY(SELECT jsonb_array_elements_text(p_payload->'deal_type_tags'));
  END IF;

  -- Dedupe step 1: exact email match, lower-normalized (only when email present)
  IF v_email IS NOT NULL THEN
    SELECT id INTO v_buyer_id
    FROM public.intake_buyers
    WHERE tenant_id = p_resolved_tenant
      AND lower(email) = lower(v_email)
    ORDER BY created_at DESC, id DESC
    LIMIT 1;
  END IF;

  -- Dedupe step 2: phone fallback ONLY when submission email is absent
  IF v_buyer_id IS NULL AND v_email IS NULL AND v_phone IS NOT NULL THEN
    SELECT id INTO v_buyer_id
    FROM public.intake_buyers
    WHERE tenant_id = p_resolved_tenant
      AND phone = v_phone
    ORDER BY created_at DESC, id DESC
    LIMIT 1;
  END IF;

  IF v_buyer_id IS NOT NULL THEN
    -- Update existing buyer record (COALESCE preserves existing when payload omits field)
    UPDATE public.intake_buyers SET
      name              = COALESCE(v_name, name),
      phone             = COALESCE(v_phone, phone),
      areas_of_interest = COALESCE(NULLIF(trim(p_payload->>'areas_of_interest'), ''), areas_of_interest),
      budget_range      = COALESCE(NULLIF(trim(p_payload->>'budget_range'), ''), budget_range),
      deal_type_tags    = COALESCE(v_deal_type_tags, deal_type_tags),
      price_range_notes = COALESCE(NULLIF(trim(p_payload->>'price_range_notes'), ''), price_range_notes),
      notes             = COALESCE(NULLIF(trim(p_payload->>'notes'), ''), notes),
      updated_at        = now()
    WHERE id = v_buyer_id AND tenant_id = p_resolved_tenant;
  ELSE
    -- Insert new buyer record
    INSERT INTO public.intake_buyers (
      tenant_id, name, email, phone,
      areas_of_interest, budget_range,
      deal_type_tags, price_range_notes, notes,
      is_active, created_at, updated_at
    ) VALUES (
      p_resolved_tenant,
      v_name,
      v_email,
      v_phone,
      NULLIF(trim(p_payload->>'areas_of_interest'), ''),
      NULLIF(trim(p_payload->>'budget_range'), ''),
      v_deal_type_tags,
      NULLIF(trim(p_payload->>'price_range_notes'), ''),
      NULLIF(trim(p_payload->>'notes'), ''),
      true,
      now(),
      now()
    )
    RETURNING id INTO v_buyer_id;
  END IF;

  RETURN v_buyer_id;
END;
$fn$;

-- Internal use only -- not callable from frontend
REVOKE ALL ON FUNCTION public.upsert_buyer_from_intake_v1(uuid, jsonb) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- RPC: submit_form_v1 (DROP + recreate -- 10.12C outcomes)
-- Seller path: stores address ONLY. No pricing fields from public intake.
-- Buyer path: calls upsert_buyer_from_intake_v1.
-- Birddog path: intake record only, no side effects.
-- asking_price and repair_estimate on draft_deals are explicitly NULL
-- for all public intake -- governed paths only populate pricing.
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
  v_tenant_id   uuid;
  v_draft_id    uuid;
  v_intake_id   uuid;
  v_buyer_id    uuid;
  v_address     text;
  v_valid_types text[] := ARRAY['buyer', 'seller', 'birddog'];
  v_spam_token  text;
  v_sub_status  text;
  v_period_end  timestamptz;
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

  -- Seller path: extract address only.
  -- Pricing fields (asking_price, repair_estimate) are NOT populated from
  -- public intake -- governed paths only (never seller public form 10.12B).
  IF p_form_type = 'seller' THEN
    v_address := NULLIF(trim(p_payload->>'address'), '');
  END IF;

  -- Insert draft deal record.
  -- asking_price and repair_estimate always NULL from public intake.
  -- address populated for seller only; NULL for buyer and birddog.
  INSERT INTO public.draft_deals (
    tenant_id, slug, form_type, payload,
    asking_price, repair_estimate, address
  ) VALUES (
    v_tenant_id, p_slug, p_form_type, p_payload,
    NULL, NULL, v_address
  )
  RETURNING id INTO v_draft_id;

  -- Persist intake record
  INSERT INTO public.intake_submissions (tenant_id, form_type, payload, source)
  VALUES (v_tenant_id, p_form_type, p_payload, 'web')
  RETURNING id INTO v_intake_id;

  -- Buyer path: upsert buyer record with deterministic dedupe
  IF p_form_type = 'buyer' THEN
    v_buyer_id := public.upsert_buyer_from_intake_v1(v_tenant_id, p_payload);
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK',
    'data', jsonb_build_object(
      'draft_id',  v_draft_id,
      'intake_id', v_intake_id,
      'buyer_id',  v_buyer_id
    ),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.submit_form_v1(text, text, jsonb) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.submit_form_v1(text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_form_v1(text, text, jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.submit_form_v1(text, text, jsonb) TO authenticated;