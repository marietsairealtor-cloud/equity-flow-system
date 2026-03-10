-- supabase/tests/8_7_share_token_usage_logging.test.sql
-- pgTAP: 8.7 Share Token Usage Logging
-- GUARDRAILS §25-28: SQL-only, no DO blocks, no backslash lines.
BEGIN;
SELECT plan(9);

SET CONSTRAINTS ALL DEFERRED;

INSERT INTO public.tenants (id) VALUES ('e8000000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
VALUES ('e8100000-0000-0000-0000-000000000001'::uuid,
        'e8000000-0000-0000-0000-000000000001'::uuid, 1, 1,
        'e8200000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
VALUES ('e8200000-0000-0000-0000-000000000001'::uuid,
        'e8000000-0000-0000-0000-000000000001'::uuid,
        'e8100000-0000-0000-0000-000000000001'::uuid, 1, 1, '{}'::jsonb);

INSERT INTO public.share_tokens (id, tenant_id, deal_id, token_hash, expires_at, revoked_at)
VALUES
  ('e8300000-0000-0000-0000-000000000001'::uuid,
   'e8000000-0000-0000-0000-000000000001'::uuid,
   'e8100000-0000-0000-0000-000000000001'::uuid,
   extensions.digest('valid_token_8_7', 'sha256'), now() + interval '30 days', NULL),
  ('e8300000-0000-0000-0000-000000000002'::uuid,
   'e8000000-0000-0000-0000-000000000001'::uuid,
   'e8100000-0000-0000-0000-000000000001'::uuid,
   extensions.digest('expired_token_8_7', 'sha256'),
   now() - interval '1 hour', NULL);

-- Test 1: Successful lookup returns OK
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'e8000000-0000-0000-0000-000000000001', true);
SELECT set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-0000000000a1', true);
SELECT is(
  (public.lookup_share_token_v1('valid_token_8_7')::json ->> 'code'),
  'OK',
  'Valid token lookup returns OK'
);

-- Test 2: Successful lookup creates activity log entry
RESET ROLE;
SELECT is(
  (SELECT count(*)::int FROM public.activity_log
   WHERE action = 'share_token_lookup'
     AND tenant_id = 'e8000000-0000-0000-0000-000000000001'::uuid
     AND (meta ->> 'success')::boolean = true),
  1,
  'Successful lookup creates activity log entry'
);

-- Test 3: Failed lookup (not found) returns NOT_FOUND
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'e8000000-0000-0000-0000-000000000001', true);
SELECT is(
  (public.lookup_share_token_v1('does_not_exist_8_7')::json ->> 'code'),
  'NOT_FOUND',
  'Not-found lookup returns NOT_FOUND'
);

-- Test 4: Failed lookup (not_found) creates activity log entry
RESET ROLE;
SELECT is(
  (SELECT count(*)::int FROM public.activity_log
   WHERE action = 'share_token_lookup'
     AND tenant_id = 'e8000000-0000-0000-0000-000000000001'::uuid
     AND meta ->> 'failure_category' = 'not_found'),
  1,
  'Failed lookup (not_found) creates activity log entry'
);

-- Test 5: Expired token lookup returns NOT_FOUND (no existence leak per 8.9)
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'e8000000-0000-0000-0000-000000000001', true);
SELECT is(
  (public.lookup_share_token_v1('expired_token_8_7')::json ->> 'code'),
  'NOT_FOUND',
  'Expired token lookup returns NOT_FOUND (no existence leak)'
);

-- Test 6: Expired token lookup creates activity log entry with failure_category=expired
RESET ROLE;
SELECT is(
  (SELECT count(*)::int FROM public.activity_log
   WHERE action = 'share_token_lookup'
     AND tenant_id = 'e8000000-0000-0000-0000-000000000001'::uuid
     AND meta ->> 'failure_category' = 'expired'),
  1,
  'Expired token lookup creates activity log entry with failure_category=expired'
);

-- Test 7: Log entries never contain raw token value
SELECT is(
  (SELECT count(*)::int FROM public.activity_log
   WHERE action = 'share_token_lookup'
     AND meta::text LIKE '%valid_token_8_7%'),
  0,
  'Activity log never contains raw token value'
);

-- Test 8: Log entries contain token_hash field
SELECT is(
  (SELECT count(*)::int FROM public.activity_log
   WHERE action = 'share_token_lookup'
     AND meta ? 'token_hash'),
  3,
  'Activity log entries contain token_hash field'
);

-- Test 9: Logging failure does not interrupt lookup RPC
-- Revoke execute on foundation_log_activity_v1 to simulate logging failure
RESET ROLE;
REVOKE EXECUTE ON FUNCTION public.foundation_log_activity_v1(text, jsonb, uuid) FROM PUBLIC, authenticated, anon;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'e8000000-0000-0000-0000-000000000001', true);
SELECT is(
  (public.lookup_share_token_v1('valid_token_8_7')::json ->> 'code'),
  'OK',
  'Lookup still returns OK when logging fails (best-effort logging confirmed)'
);
-- Restore execute permission
RESET ROLE;
GRANT EXECUTE ON FUNCTION public.foundation_log_activity_v1(text, jsonb, uuid) TO authenticated;

SELECT finish();
ROLLBACK;
