-- supabase/tests/9_5_token_cardinality_guard.test.sql
-- pgTAP: 9.5 Share Token Cardinality Guard
-- Proves: creation fails when active token count >= 50.
-- Revoked and expired tokens do not count toward limit.
-- Creation succeeds under limit.
-- GUARDRAILS SS25-28: SQL-only, no DO blocks, no backslash lines.
BEGIN;
SELECT plan(5);

SET CONSTRAINTS ALL DEFERRED;

INSERT INTO public.tenants (id) VALUES ('ed000000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
VALUES ('ed100000-0000-0000-0000-000000000001'::uuid,
        'ed000000-0000-0000-0000-000000000001'::uuid, 1, 1,
        'ed200000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
VALUES ('ed200000-0000-0000-0000-000000000001'::uuid,
        'ed000000-0000-0000-0000-000000000001'::uuid,
        'ed100000-0000-0000-0000-000000000001'::uuid, 1, 1, '{}'::jsonb);

-- Seed 49 active tokens (under limit)
INSERT INTO public.share_tokens (id, tenant_id, deal_id, token_hash, expires_at)
SELECT
  gen_random_uuid(),
  'ed000000-0000-0000-0000-000000000001'::uuid,
  'ed100000-0000-0000-0000-000000000001'::uuid,
  extensions.digest('seed_token_' || i::text, 'sha256'),
  now() + interval '1 hour'
FROM generate_series(1, 49) AS i;

-- Seed 1 revoked token (must NOT count toward limit)
INSERT INTO public.share_tokens (id, tenant_id, deal_id, token_hash, expires_at, revoked_at)
VALUES ('ed300000-0000-0000-0000-000000000001'::uuid,
        'ed000000-0000-0000-0000-000000000001'::uuid,
        'ed100000-0000-0000-0000-000000000001'::uuid,
        extensions.digest('revoked_seed_9_5', 'sha256'),
        now() + interval '1 hour',
        now() - interval '1 minute');

-- Seed 1 expired token (must NOT count toward limit)
INSERT INTO public.share_tokens (id, tenant_id, deal_id, token_hash, expires_at)
VALUES ('ed300000-0000-0000-0000-000000000002'::uuid,
        'ed000000-0000-0000-0000-000000000001'::uuid,
        'ed100000-0000-0000-0000-000000000001'::uuid,
        extensions.digest('expired_seed_9_5', 'sha256'),
        now() - interval '1 hour');

RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'ed000000-0000-0000-0000-000000000001', true);
SELECT set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-0000000000a1', true);

-- Test 1: Creation succeeds at 49 active tokens (under limit)
-- Revoked and expired tokens are excluded from count.
SELECT is(
  (public.create_share_token_v1('ed100000-0000-0000-0000-000000000001'::uuid, now() + interval '1 hour')::json ->> 'code'),
  'OK',
  'Token creation succeeds at 49 active tokens (under limit of 50)'
);

-- Now 50 active tokens exist. Next creation must fail.

-- Test 2: Creation fails at 50 active tokens (limit reached)
SELECT is(
  (public.create_share_token_v1('ed100000-0000-0000-0000-000000000001'::uuid, now() + interval '1 hour')::json ->> 'code'),
  'CONFLICT',
  'Token creation fails at 50 active tokens (limit reached)'
);

-- Test 3: CONFLICT response contains expected message
SELECT is(
  (public.create_share_token_v1('ed100000-0000-0000-0000-000000000001'::uuid, now() + interval '1 hour')::json -> 'error' ->> 'message'),
  'Active token limit reached for this resource',
  'CONFLICT response contains expected message'
);

-- Revoke one active token via subquery (no LIMIT in UPDATE — use ctid trick)
RESET ROLE;
UPDATE public.share_tokens
SET revoked_at = now()
WHERE id = (
  SELECT id FROM public.share_tokens
  WHERE tenant_id  = 'ed000000-0000-0000-0000-000000000001'::uuid
    AND deal_id    = 'ed100000-0000-0000-0000-000000000001'::uuid
    AND revoked_at IS NULL
    AND expires_at > now()
  ORDER BY id
  LIMIT 1
);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'ed000000-0000-0000-0000-000000000001', true);

-- Test 4: Creation succeeds after revoking one token (active count drops to 49)
SELECT is(
  (public.create_share_token_v1('ed100000-0000-0000-0000-000000000001'::uuid, now() + interval '1 hour')::json ->> 'code'),
  'OK',
  'Token creation succeeds after revoking one token (revoked tokens free capacity)'
);

-- Test 5: create_share_token_v1 function exists with correct signature
SELECT has_function('public', 'create_share_token_v1', ARRAY['uuid', 'timestamp with time zone'],
  'create_share_token_v1(uuid, timestamptz) exists'
);

SELECT finish();
ROLLBACK;