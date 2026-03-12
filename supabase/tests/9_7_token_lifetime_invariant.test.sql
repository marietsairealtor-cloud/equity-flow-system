-- supabase/tests/9_7_token_lifetime_invariant.test.sql
-- pgTAP: 9.7 Share Token Maximum Lifetime Invariant
-- Proves: expires_at > now() + 90 days rejected with VALIDATION_ERROR.
-- Valid lifetime succeeds. Expired tokens rejected. Field-level error present.
-- GUARDRAILS SS25-28: SQL-only, no DO blocks, no backslash lines.
BEGIN;
SELECT plan(7);

SET CONSTRAINTS ALL DEFERRED;

INSERT INTO public.tenants (id) VALUES ('ee000000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
VALUES ('ee100000-0000-0000-0000-000000000001'::uuid,
        'ee000000-0000-0000-0000-000000000001'::uuid, 1, 1,
        'ee200000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
VALUES ('ee200000-0000-0000-0000-000000000001'::uuid,
        'ee000000-0000-0000-0000-000000000001'::uuid,
        'ee100000-0000-0000-0000-000000000001'::uuid, 1, 1, '{}'::jsonb);

RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'ee000000-0000-0000-0000-000000000001', true);
SELECT set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-0000000000a1', true);

-- Test 1: Valid lifetime (1 hour) succeeds
SELECT is(
  (public.create_share_token_v1(
    'ee100000-0000-0000-0000-000000000001'::uuid,
    now() + interval '1 hour'
  )::json ->> 'code'),
  'OK',
  'Token creation succeeds with valid lifetime (1 hour)'
);

-- Test 2: Valid lifetime (exactly 90 days) succeeds
SELECT is(
  (public.create_share_token_v1(
    'ee100000-0000-0000-0000-000000000001'::uuid,
    now() + interval '90 days'
  )::json ->> 'code'),
  'OK',
  'Token creation succeeds at exactly 90 days lifetime'
);

-- Test 3: Excessive lifetime (91 days) rejected with VALIDATION_ERROR
SELECT is(
  (public.create_share_token_v1(
    'ee100000-0000-0000-0000-000000000001'::uuid,
    now() + interval '91 days'
  )::json ->> 'code'),
  'VALIDATION_ERROR',
  'Token creation fails with VALIDATION_ERROR for lifetime > 90 days'
);

-- Test 4: Excessive lifetime error message references max lifetime
SELECT is(
  (public.create_share_token_v1(
    'ee100000-0000-0000-0000-000000000001'::uuid,
    now() + interval '91 days'
  )::json -> 'error' ->> 'message'),
  'expires_at exceeds maximum allowed lifetime of 90 days',
  'VALIDATION_ERROR message references maximum lifetime of 90 days'
);

-- Test 5: Field-level error present on expires_at
SELECT is(
  (public.create_share_token_v1(
    'ee100000-0000-0000-0000-000000000001'::uuid,
    now() + interval '91 days'
  )::json -> 'error' -> 'fields' ->> 'expires_at'),
  'Maximum token lifetime is 90 days',
  'Field-level error present on expires_at for excessive lifetime'
);

-- Test 6: Expired token (in the past) rejected with VALIDATION_ERROR
SELECT is(
  (public.create_share_token_v1(
    'ee100000-0000-0000-0000-000000000001'::uuid,
    now() - interval '1 hour'
  )::json ->> 'code'),
  'VALIDATION_ERROR',
  'Token creation fails with VALIDATION_ERROR for expires_at in the past'
);

-- Test 7: create_share_token_v1 function exists with correct signature
SELECT has_function('public', 'create_share_token_v1', ARRAY['uuid', 'timestamp with time zone'],
  'create_share_token_v1(uuid, timestamptz) exists'
);

SELECT finish();
ROLLBACK;