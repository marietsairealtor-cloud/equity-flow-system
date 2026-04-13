-- supabase/tests/8_10_share_token_scope_enforcement.test.sql
-- pgTAP: 8.10 Share Token Scope Enforcement
-- Proves: deal_id scope enforced, cross-resource fails, no existence leak.
-- GUARDRAILS S25-28: SQL-only, no DO blocks, no backslash lines.
BEGIN;
SELECT plan(7);

SET CONSTRAINTS ALL DEFERRED;

INSERT INTO public.tenants (id) VALUES ('eb000000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
VALUES ('eb000000-0000-0000-0000-000000000001'::uuid, 'active', now() + interval '1 year');

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
VALUES
  ('eb100000-0000-0000-0000-000000000001'::uuid,
   'eb000000-0000-0000-0000-000000000001'::uuid, 1, 1,
   'eb200000-0000-0000-0000-000000000001'::uuid),
  ('eb100000-0000-0000-0000-000000000002'::uuid,
   'eb000000-0000-0000-0000-000000000001'::uuid, 1, 1,
   'eb200000-0000-0000-0000-000000000002'::uuid);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
VALUES
  ('eb200000-0000-0000-0000-000000000001'::uuid,
   'eb000000-0000-0000-0000-000000000001'::uuid,
   'eb100000-0000-0000-0000-000000000001'::uuid, 1, 1, '{}'::jsonb),
  ('eb200000-0000-0000-0000-000000000002'::uuid,
   'eb000000-0000-0000-0000-000000000001'::uuid,
   'eb100000-0000-0000-0000-000000000002'::uuid, 1, 1, '{}'::jsonb);

INSERT INTO public.share_tokens (id, tenant_id, deal_id, token_hash, expires_at)
VALUES
  ('eb300000-0000-0000-0000-000000000001'::uuid,
   'eb000000-0000-0000-0000-000000000001'::uuid,
   'eb100000-0000-0000-0000-000000000001'::uuid,
   extensions.digest('shr_8a000000000000000000000000000000000000000000000000000000000000aa', 'sha256'),
   now() + interval '1 hour');

RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'eb000000-0000-0000-0000-000000000001', true);
SELECT set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-0000000000a1', true);

-- Test 1: Token resolves for correct deal
SELECT is(
  (public.lookup_share_token_v1('shr_8a000000000000000000000000000000000000000000000000000000000000aa', 'eb100000-0000-0000-0000-000000000001'::uuid)::json ->> 'code'),
  'OK',
  'Token resolves for correct deal'
);

-- Test 2: Token fails for different deal (cross-resource)
SELECT is(
  (public.lookup_share_token_v1('shr_8a000000000000000000000000000000000000000000000000000000000000aa', 'eb100000-0000-0000-0000-000000000002'::uuid)::json ->> 'code'),
  'NOT_FOUND',
  'Token fails for different deal (cross-resource rejection)'
);

-- Test 3: Cross-resource response code identical to nonexistent token
SELECT is(
  (public.lookup_share_token_v1('shr_8a000000000000000000000000000000000000000000000000000000000000aa', 'eb100000-0000-0000-0000-000000000002'::uuid)::json ->> 'code'),
  (public.lookup_share_token_v1('shr_8a000000000000000000000000000000000000000000000000000000000000bb', 'eb100000-0000-0000-0000-000000000001'::uuid)::json ->> 'code'),
  'Cross-resource response code identical to nonexistent token (no existence leak)'
);

-- Test 4: Cross-resource error message identical to nonexistent token
SELECT is(
  (public.lookup_share_token_v1('shr_8a000000000000000000000000000000000000000000000000000000000000aa', 'eb100000-0000-0000-0000-000000000002'::uuid)::json -> 'error' ->> 'message'),
  (public.lookup_share_token_v1('shr_8a000000000000000000000000000000000000000000000000000000000000bb', 'eb100000-0000-0000-0000-000000000001'::uuid)::json -> 'error' ->> 'message'),
  'Cross-resource error message identical to nonexistent token (no existence leak)'
);

-- Test 5: Resolved token data contains correct deal_id
SELECT is(
  (public.lookup_share_token_v1('shr_8a000000000000000000000000000000000000000000000000000000000000aa', 'eb100000-0000-0000-0000-000000000001'::uuid)::json -> 'data' ->> 'deal_id'),
  'eb100000-0000-0000-0000-000000000001',
  'Resolved token data contains correct deal_id'
);

-- Test 6: lookup_share_token_v1 function exists with new signature
SELECT has_function('public', 'lookup_share_token_v1', ARRAY['text', 'uuid'],
  'lookup_share_token_v1(text, uuid) exists'
);

-- Test 7: Old single-arg signature no longer exists
SELECT hasnt_function('public', 'lookup_share_token_v1', ARRAY['text'],
  'lookup_share_token_v1(text) no longer exists'
);

SELECT finish();
ROLLBACK;
