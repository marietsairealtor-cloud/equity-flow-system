-- 10.8.11N: Expired Subscription Server-Side Write Lock
-- Adds check_workspace_write_allowed_v1() helper and applies write lock
-- to all write RPCs. Blocked writes return contract-valid error envelope.
-- Profile settings (update_display_name_v1) and billing path are exempt.
-- lookup_share_token_v1 and submit_form_v1 use inline subscription check
-- because they resolve tenant via slug, not membership context.

-- ============================================================
-- Helper: check_workspace_write_allowed_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.check_workspace_write_allowed_v1()
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant      uuid;
  v_status      text;
  v_period_end  timestamptz;
BEGIN
  v_tenant := public.current_tenant_id();

  IF v_tenant IS NULL THEN
    RETURN false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.tenant_memberships tm
    WHERE tm.tenant_id = v_tenant AND tm.user_id = auth.uid()
  ) THEN
    RETURN false;
  END IF;

  SELECT ts.status, ts.current_period_end INTO v_status, v_period_end
  FROM public.tenant_subscriptions ts WHERE ts.tenant_id = v_tenant;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF v_status = 'canceled' OR v_period_end <= now() THEN
    RETURN false;
  END IF;

  RETURN true;
END;
$fn$;

REVOKE ALL ON FUNCTION public.check_workspace_write_allowed_v1() FROM PUBLIC;

-- ============================================================
-- create_deal_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.create_deal_v1(p_id uuid, p_calc_version integer DEFAULT 1, p_assumptions jsonb DEFAULT '{}'::jsonb)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant      uuid;
  v_snapshot_id uuid;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object()));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', json_build_object()));
  END IF;

  v_snapshot_id := gen_random_uuid();

  INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
  VALUES (p_id, v_tenant, 1, p_calc_version, v_snapshot_id);

  INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
  VALUES (v_snapshot_id, v_tenant, p_id, p_calc_version, 1, p_assumptions);

  RETURN json_build_object('ok', true, 'code', 'OK',
    'data', json_build_object('id', p_id, 'tenant_id', v_tenant, 'assumptions_snapshot_id', v_snapshot_id),
    'error', null);
EXCEPTION WHEN unique_violation THEN
  RETURN json_build_object('ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
    'error', json_build_object('message', 'Deal already exists', 'fields', json_build_object()));
END;
$fn$;

-- ============================================================
-- update_deal_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_deal_v1(p_id uuid, p_expected_row_version bigint, p_calc_version integer DEFAULT NULL::integer)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant      uuid;
  v_stage       text;
  v_rows_updated int;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object()));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', json_build_object()));
  END IF;

  SELECT stage INTO v_stage FROM public.deals WHERE id = p_id AND tenant_id = v_tenant;

  IF v_stage IN ('Closed / Dead') THEN
    RETURN json_build_object('ok', false, 'code', 'DEAL_IMMUTABLE', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal is in a terminal stage and cannot be modified', 'fields', json_build_object()));
  END IF;

  UPDATE public.deals
  SET row_version = row_version + 1, calc_version = COALESCE(p_calc_version, calc_version)
  WHERE id = p_id AND tenant_id = v_tenant AND row_version = p_expected_row_version;

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
    RETURN json_build_object('ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Row version mismatch or deal not found for this tenant', 'fields', json_build_object()));
  END IF;

  RETURN json_build_object('ok', true, 'code', 'OK', 'data', json_build_object('id', p_id), 'error', null);
END;
$fn$;

-- ============================================================
-- create_farm_area_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.create_farm_area_v1(p_area_name text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
  v_new_id uuid;
BEGIN
  PERFORM public.require_min_role_v1('admin');

  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', '{}'::jsonb));
  END IF;

  IF p_area_name IS NULL OR btrim(p_area_name) = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Area name is required', 'fields', jsonb_build_object('area_name', 'Must not be blank')));
  END IF;

  INSERT INTO public.tenant_farm_areas (tenant_id, area_name)
  VALUES (v_tenant_id, btrim(p_area_name)) RETURNING id INTO v_new_id;

  RETURN jsonb_build_object('ok', true, 'code', 'OK',
    'data', jsonb_build_object('farm_area_id', v_new_id, 'area_name', btrim(p_area_name)), 'error', null);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('ok', false, 'code', 'CONFLICT', 'data', '{}'::jsonb,
    'error', jsonb_build_object('message', 'Farm area already exists', 'fields', jsonb_build_object('area_name', 'Already exists in this workspace')));
END;
$fn$;

-- ============================================================
-- delete_farm_area_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.delete_farm_area_v1(p_farm_area_id uuid)
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
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', '{}'::jsonb));
  END IF;

  IF p_farm_area_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'farm_area_id is required', 'fields', jsonb_build_object('farm_area_id', 'Must not be null')));
  END IF;

  DELETE FROM public.tenant_farm_areas WHERE id = p_farm_area_id AND tenant_id = v_tenant_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Farm area not found', 'fields', '{}'::jsonb));
  END IF;

  RETURN jsonb_build_object('ok', true, 'code', 'OK',
    'data', jsonb_build_object('farm_area_id', p_farm_area_id), 'error', null);
END;
$fn$;

-- ============================================================
-- create_reminder_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.create_reminder_v1(p_deal_id uuid, p_reminder_date timestamp with time zone, p_reminder_type text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant      uuid;
  v_reminder_id uuid;
BEGIN
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'Not authorized', 'fields', json_build_object()));
  END;

  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object()));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', json_build_object()));
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Invalid input', 'fields', json_build_object('deal_id', 'Required')));
  END IF;

  IF p_reminder_date IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Invalid input', 'fields', json_build_object('reminder_date', 'Required')));
  END IF;

  IF p_reminder_type IS NULL OR trim(p_reminder_type) = '' THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Invalid input', 'fields', json_build_object('reminder_type', 'Required')));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.deals d WHERE d.id = p_deal_id AND d.tenant_id = v_tenant) THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object()));
  END IF;

  INSERT INTO public.deal_reminders (deal_id, tenant_id, reminder_date, reminder_type)
  VALUES (p_deal_id, v_tenant, p_reminder_date, p_reminder_type) RETURNING id INTO v_reminder_id;

  RETURN json_build_object('ok', true, 'code', 'OK', 'data', json_build_object('id', v_reminder_id), 'error', null);
END;
$fn$;

-- ============================================================
-- complete_reminder_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.complete_reminder_v1(p_reminder_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant uuid;
BEGIN
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'Not authorized', 'fields', json_build_object()));
  END;

  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object()));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', json_build_object()));
  END IF;

  IF p_reminder_id IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Invalid input', 'fields', json_build_object('reminder_id', 'Required')));
  END IF;

  UPDATE public.deal_reminders SET completed_at = now()
  WHERE id = p_reminder_id AND tenant_id = v_tenant AND completed_at IS NULL;

  RETURN json_build_object('ok', true, 'code', 'OK', 'data', json_build_object('id', p_reminder_id), 'error', null);
END;
$fn$;

-- ============================================================
-- create_share_token_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.create_share_token_v1(p_deal_id uuid, p_expires_at timestamp with time zone)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id    uuid;
  v_token        text;
  v_hash         bytea;
  v_active_count int;
  v_max_tokens   constant int := 50;
BEGIN
  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object()));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', json_build_object()));
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'deal_id is required', 'fields', json_build_object()));
  END IF;
  IF p_expires_at IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'expires_at is required', 'fields', json_build_object()));
  END IF;
  IF p_expires_at <= now() THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'expires_at must be in the future', 'fields', json_build_object()));
  END IF;
  IF p_expires_at > now() + interval '90 days' THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'expires_at exceeds maximum allowed lifetime of 90 days',
        'fields', json_build_object('expires_at', 'Maximum token lifetime is 90 days')));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.deals WHERE id = p_deal_id AND tenant_id = v_tenant_id) THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object()));
  END IF;

  SELECT count(*)::int INTO v_active_count FROM public.share_tokens
  WHERE deal_id = p_deal_id AND tenant_id = v_tenant_id AND revoked_at IS NULL AND expires_at > now();

  IF v_active_count >= v_max_tokens THEN
    RETURN json_build_object('ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Active token limit reached for this resource', 'fields', json_build_object()));
  END IF;

  v_token := 'shr_' || encode(extensions.gen_random_bytes(32), 'hex');
  v_hash  := extensions.digest(v_token, 'sha256');

  INSERT INTO public.share_tokens (tenant_id, deal_id, token_hash, expires_at)
  VALUES (v_tenant_id, p_deal_id, v_hash, p_expires_at);

  RETURN json_build_object('ok', true, 'code', 'OK',
    'data', json_build_object('token', v_token, 'expires_at', p_expires_at), 'error', null);
END;
$fn$;

-- ============================================================
-- update_workspace_settings_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_workspace_settings_v1(p_workspace_name text DEFAULT NULL::text, p_slug text DEFAULT NULL::text, p_country text DEFAULT NULL::text, p_currency text DEFAULT NULL::text, p_measurement_unit text DEFAULT NULL::text)
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
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', '{}'::jsonb));
  END IF;

  IF p_workspace_name IS NOT NULL AND btrim(p_workspace_name) = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invalid workspace name', 'fields', jsonb_build_object('workspace_name', 'Must not be blank')));
  END IF;
  IF p_country IS NOT NULL AND btrim(p_country) = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invalid country', 'fields', jsonb_build_object('country', 'Must not be blank')));
  END IF;
  IF p_currency IS NOT NULL AND btrim(p_currency) = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invalid currency', 'fields', jsonb_build_object('currency', 'Must not be blank')));
  END IF;
  IF p_measurement_unit IS NOT NULL AND btrim(p_measurement_unit) = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invalid measurement unit', 'fields', jsonb_build_object('measurement_unit', 'Must not be blank')));
  END IF;
  IF p_slug IS NOT NULL THEN
    IF btrim(p_slug) = '' OR p_slug !~ '^[a-z0-9][a-z0-9\-]{1,48}[a-z0-9]$' THEN
      RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'Invalid slug format', 'fields', jsonb_build_object('slug', 'Must be lowercase, URL-safe, 3-50 characters')));
    END IF;
    BEGIN
      INSERT INTO public.tenant_slugs (tenant_id, slug) VALUES (v_tenant_id, p_slug)
      ON CONFLICT (tenant_id) DO UPDATE SET slug = EXCLUDED.slug WHERE tenant_slugs.tenant_id = v_tenant_id;
    EXCEPTION WHEN unique_violation THEN
      RETURN jsonb_build_object('ok', false, 'code', 'CONFLICT', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'Slug already taken', 'fields', jsonb_build_object('slug', 'Already in use')));
    END;
  END IF;

  UPDATE public.tenants SET
    name = COALESCE(p_workspace_name, name),
    country = COALESCE(p_country, country),
    currency = COALESCE(p_currency, currency),
    measurement_unit = COALESCE(p_measurement_unit, measurement_unit)
  WHERE id = v_tenant_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Workspace not found', 'fields', '{}'::jsonb));
  END IF;

  RETURN jsonb_build_object('ok', true, 'code', 'OK',
    'data', jsonb_build_object(
      'tenant_id', v_tenant_id,
      'workspace_name', COALESCE(p_workspace_name, (SELECT name FROM public.tenants WHERE id = v_tenant_id)),
      'slug', COALESCE(p_slug, (SELECT slug FROM public.tenant_slugs WHERE tenant_id = v_tenant_id LIMIT 1)),
      'country', COALESCE(p_country, (SELECT country FROM public.tenants WHERE id = v_tenant_id)),
      'currency', COALESCE(p_currency, (SELECT currency FROM public.tenants WHERE id = v_tenant_id)),
      'measurement_unit', COALESCE(p_measurement_unit, (SELECT measurement_unit FROM public.tenants WHERE id = v_tenant_id))
    ), 'error', null);
END;
$fn$;

-- ============================================================
-- update_member_role_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_member_role_v1(p_user_id uuid, p_role tenant_role)
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
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', '{}'::jsonb));
  END IF;

  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'user_id is required', 'fields', jsonb_build_object('user_id', 'Must not be null')));
  END IF;
  IF p_role IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Role is required', 'fields', jsonb_build_object('role', 'Must not be null')));
  END IF;

  UPDATE public.tenant_memberships SET role = p_role WHERE tenant_id = v_tenant_id AND user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Member not found', 'fields', '{}'::jsonb));
  END IF;

  RETURN jsonb_build_object('ok', true, 'code', 'OK',
    'data', jsonb_build_object('user_id', p_user_id, 'role', p_role), 'error', null);
END;
$fn$;

-- ============================================================
-- remove_member_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.remove_member_v1(p_user_id uuid)
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
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', '{}'::jsonb));
  END IF;

  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'user_id is required', 'fields', jsonb_build_object('user_id', 'Must not be null')));
  END IF;

  DELETE FROM public.tenant_memberships WHERE tenant_id = v_tenant_id AND user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Member not found', 'fields', '{}'::jsonb));
  END IF;

  RETURN jsonb_build_object('ok', true, 'code', 'OK',
    'data', jsonb_build_object('user_id', p_user_id), 'error', null);
END;
$fn$;

-- ============================================================
-- invite_workspace_member_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.invite_workspace_member_v1(p_email text, p_role tenant_role)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
  v_existing_member uuid;
  v_existing_invite uuid;
BEGIN
  PERFORM public.require_min_role_v1('admin');

  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', '{}'::jsonb));
  END IF;

  IF p_email IS NULL OR btrim(p_email) = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Email is required', 'fields', jsonb_build_object('email', 'Must not be blank')));
  END IF;
  IF p_role IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Role is required', 'fields', jsonb_build_object('role', 'Must not be null')));
  END IF;

  SELECT tm.user_id INTO v_existing_member FROM public.tenant_memberships tm
  JOIN auth.users u ON u.id = tm.user_id
  WHERE tm.tenant_id = v_tenant_id AND lower(u.email) = lower(btrim(p_email));

  IF v_existing_member IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'CONFLICT', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'User is already a member', 'fields', jsonb_build_object('email', 'Already a member of this workspace')));
  END IF;

  SELECT id INTO v_existing_invite FROM public.tenant_invites
  WHERE tenant_id = v_tenant_id AND lower(invited_email) = lower(btrim(p_email))
    AND accepted_at IS NULL AND expires_at > now();

  IF v_existing_invite IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'CONFLICT', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Pending invite already exists', 'fields', jsonb_build_object('email', 'Already has a pending invite')));
  END IF;

  INSERT INTO public.tenant_invites (tenant_id, invited_email, role, token, invited_by, expires_at)
  VALUES (v_tenant_id, lower(btrim(p_email)), p_role, gen_random_uuid()::text, auth.uid(), now() + interval '7 days');

  RETURN jsonb_build_object('ok', true, 'code', 'OK',
    'data', jsonb_build_object('invited_email', lower(btrim(p_email)), 'role', p_role), 'error', null);
END;
$fn$;

-- ============================================================
-- submit_form_v1 -- blocked when workspace expired
-- Inline subscription check: slug-based resolution, no membership context
-- ============================================================
CREATE OR REPLACE FUNCTION public.submit_form_v1(p_slug text, p_form_type text, p_payload jsonb)
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
  v_sub_status    text;
  v_period_end    timestamptz;
BEGIN
  IF p_form_type IS NULL OR NOT (p_form_type = ANY(v_valid_types)) THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Invalid form type',
        'fields', json_build_object('form_type', 'Must be buyer, seller, or birddog')));
  END IF;
  IF p_slug IS NULL OR p_slug !~ '^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$' THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Not found', 'fields', '{}'::json));
  END IF;
  IF p_payload IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Payload required', 'fields', json_build_object('payload', 'Required')));
  END IF;

  v_spam_token := p_payload->>'spam_token';
  IF v_spam_token IS NULL OR length(trim(v_spam_token)) = 0 THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Spam protection token required',
        'fields', json_build_object('spam_token', 'Required')));
  END IF;

  SELECT ts.tenant_id INTO v_tenant_id FROM public.tenant_slugs ts WHERE ts.slug = p_slug;
  IF v_tenant_id IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Not found', 'fields', '{}'::json));
  END IF;

  -- Block submissions for expired workspaces
  SELECT ts.status, ts.current_period_end INTO v_sub_status, v_period_end
  FROM public.tenant_subscriptions ts WHERE ts.tenant_id = v_tenant_id;

  IF NOT FOUND OR v_sub_status = 'canceled' OR v_period_end <= now() THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is not accepting submissions.', 'fields', json_build_object()));
  END IF;

  IF p_form_type = 'seller' THEN
    v_asking_price := (p_payload->>'asking_price')::numeric;
    v_repair_est   := (p_payload->>'repair_estimate')::numeric;
  END IF;

  INSERT INTO public.draft_deals (tenant_id, slug, form_type, payload, asking_price, repair_estimate)
  VALUES (v_tenant_id, p_slug, p_form_type, p_payload, v_asking_price, v_repair_est)
  RETURNING id INTO v_draft_id;

  RETURN json_build_object('ok', true, 'code', 'OK',
    'data', json_build_object('draft_id', v_draft_id), 'error', null);
END;
$fn$;

-- ============================================================
-- lookup_share_token_v1 -- blocked when workspace expired
-- Inline subscription check: tenant context via JWT, not slug
-- ============================================================
CREATE OR REPLACE FUNCTION public.lookup_share_token_v1(p_token text, p_deal_id uuid)
RETURNS json
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id  uuid;
  v_row        record;
  v_hash       bytea;
  v_result     json;
  v_sub_status text;
  v_period_end timestamptz;
BEGIN
  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object()));
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'deal_id is required', 'fields', json_build_object()));
  END IF;

  -- Block share link access for expired workspaces
  SELECT ts.status, ts.current_period_end INTO v_sub_status, v_period_end
  FROM public.tenant_subscriptions ts WHERE ts.tenant_id = v_tenant_id;

  IF NOT FOUND OR v_sub_status = 'canceled' OR v_period_end <= now() THEN
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', null, 'success', false, 'failure_category', 'workspace_expired')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object()));
  END IF;

  IF p_token IS NULL OR length(p_token) < 68 OR left(p_token, 4) <> 'shr_'
     OR substring(p_token FROM 5) !~ '^[0-9a-f]{64}$'
  THEN
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', null, 'success', false, 'failure_category', 'format_invalid')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object()));
  END IF;

  v_hash := extensions.digest(p_token, 'sha256');

  SELECT st.deal_id, st.expires_at, st.revoked_at, d.calc_version INTO v_row
  FROM public.share_tokens st
  JOIN public.deals d ON d.id = st.deal_id AND d.tenant_id = st.tenant_id
  WHERE st.token_hash = v_hash AND st.tenant_id = v_tenant_id AND st.deal_id = p_deal_id;

  IF NOT FOUND THEN
    v_result := json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object()));
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'not_found')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN v_result;
  END IF;

  IF v_row.revoked_at IS NOT NULL THEN
    v_result := json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object()));
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'revoked')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN v_result;
  END IF;

  IF v_row.expires_at <= now() THEN
    v_result := json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object()));
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'expired')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN v_result;
  END IF;

  v_result := json_build_object('ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', v_row.deal_id, 'calc_version', v_row.calc_version, 'expires_at', v_row.expires_at),
    'error', null);
  BEGIN
    PERFORM public.foundation_log_activity_v1('share_token_lookup',
      json_build_object('token_hash', encode(v_hash, 'hex'), 'success', true, 'failure_category', null)::jsonb, null);
  EXCEPTION WHEN OTHERS THEN NULL; END;
  RETURN v_result;
END;
$fn$;