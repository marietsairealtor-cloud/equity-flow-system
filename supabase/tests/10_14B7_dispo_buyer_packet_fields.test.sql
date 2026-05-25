-- 10.14B7: Dispo Backend -- Buyer-Facing Packet Fields tests
BEGIN;

SELECT plan(40);

-- Seed tenant + owner + member
SELECT public.create_active_workspace_seed_v1(
  'b1145700-0000-0000-0000-000000000001'::uuid,
  'a1145700-0000-0000-0000-000000000001'::uuid,
  'owner'
);

SELECT public.create_active_workspace_seed_v1(
  'b1145700-0000-0000-0000-000000000001'::uuid,
  'a1145700-0000-0000-0000-000000000002'::uuid,
  'member'
);

-- Seed cross-tenant
SELECT public.create_active_workspace_seed_v1(
  'b1145700-0000-0000-0000-000000000002'::uuid,
  'a1145700-0000-0000-0000-000000000099'::uuid,
  'owner'
);

-- Seed workspace-expired tenant
INSERT INTO public.tenants (id) VALUES ('b1145700-0000-0000-0000-000000000003'::uuid) ON CONFLICT DO NOTHING;
INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
VALUES ('b1145700-0000-0000-0000-000000000003'::uuid, 'canceled', now() - interval '1 day')
ON CONFLICT DO NOTHING;

-- Seed deals
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1145700-0000-0000-0000-000000000001',
  'b1145700-0000-0000-0000-000000000001',
  1, 1, 'dispo', '100 Packet St', now(), now()
);

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1145700-0000-0000-0000-000000000003',
  'b1145700-0000-0000-0000-000000000001',
  1, 1, 'new', '300 New St', now(), now()
);

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1145700-0000-0000-0000-000000000099',
  'b1145700-0000-0000-0000-000000000002',
  1, 1, 'dispo', '999 Other St', now(), now()
);

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1145700-0000-0000-0000-000000000004',
  'b1145700-0000-0000-0000-000000000003',
  1, 1, 'dispo', '400 Expired St', now(), now()
);

-- Seed share tokens
INSERT INTO public.share_tokens (id, tenant_id, deal_id, token_hash, expires_at)
VALUES (
  'f1145700-0000-0000-0000-000000000001',
  'b1145700-0000-0000-0000-000000000001',
  'd1145700-0000-0000-0000-000000000001',
  extensions.digest('shr_b7000000000000000000000000000000000000000000000000000000000000aa', 'sha256'),
  now() + interval '30 days'
);

INSERT INTO public.share_tokens (id, tenant_id, deal_id, token_hash, expires_at, revoked_at)
VALUES (
  'f1145700-0000-0000-0000-000000000002',
  'b1145700-0000-0000-0000-000000000001',
  'd1145700-0000-0000-0000-000000000001',
  extensions.digest('shr_b7000000000000000000000000000000000000000000000000000000000000bb', 'sha256'),
  now() + interval '30 days',
  now()
);

INSERT INTO public.share_tokens (id, tenant_id, deal_id, token_hash, expires_at)
VALUES (
  'f1145700-0000-0000-0000-000000000003',
  'b1145700-0000-0000-0000-000000000001',
  'd1145700-0000-0000-0000-000000000001',
  extensions.digest('shr_b7000000000000000000000000000000000000000000000000000000000000cc', 'sha256'),
  '2020-01-01 00:00:00+00'
);

INSERT INTO public.share_tokens (id, tenant_id, deal_id, token_hash, expires_at)
VALUES (
  'f1145700-0000-0000-0000-000000000004',
  'b1145700-0000-0000-0000-000000000003',
  'd1145700-0000-0000-0000-000000000004',
  extensions.digest('shr_b7000000000000000000000000000000000000000000000000000000000000dd', 'sha256'),
  now() + interval '30 days'
);

-- Set context: tenant one owner
SELECT set_config('request.jwt.claims',
  '{"sub":"a1145700-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1145700-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- 1. saves packet fields
SELECT is(
  (public.update_dispo_packet_v1(
    'd1145700-0000-0000-0000-000000000001',
    '{"dispo_asking_price":250000,"dispo_intersection":"Main & Elm","dispo_description":"Nice deal","dispo_market_value_estimate":300000}'::jsonb
  )::json)->>'code',
  'OK',
  'update_dispo_packet_v1: saves packet fields'
);

-- 2. saved fields persist
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT dispo_intersection FROM public.deals WHERE id = 'd1145700-0000-0000-0000-000000000001'),
  'Main & Elm',
  'update_dispo_packet_v1: dispo_intersection persists'
);
SET LOCAL ROLE authenticated;

-- 3. patch preserves omitted fields
SELECT is(
  (public.update_dispo_packet_v1(
    'd1145700-0000-0000-0000-000000000001',
    '{"dispo_description":"Updated desc"}'::jsonb
  )::json)->>'code',
  'OK',
  'update_dispo_packet_v1: partial patch succeeds'
);

SET LOCAL ROLE postgres;
SELECT is(
  (SELECT dispo_intersection FROM public.deals WHERE id = 'd1145700-0000-0000-0000-000000000001'),
  'Main & Elm',
  'update_dispo_packet_v1: omitted field preserved after patch'
);
SET LOCAL ROLE authenticated;

-- 4. explicit null clears field
SELECT is(
  (public.update_dispo_packet_v1(
    'd1145700-0000-0000-0000-000000000001',
    '{"dispo_intersection":null}'::jsonb
  )::json)->>'code',
  'OK',
  'update_dispo_packet_v1: explicit null patch returns OK'
);

SET LOCAL ROLE postgres;
SELECT is(
  (SELECT dispo_intersection FROM public.deals WHERE id = 'd1145700-0000-0000-0000-000000000001'),
  NULL,
  'update_dispo_packet_v1: field cleared after explicit null'
);
SET LOCAL ROLE authenticated;

-- 5. empty string normalizes to NULL
SELECT is(
  (public.update_dispo_packet_v1(
    'd1145700-0000-0000-0000-000000000001',
    '{"dispo_description":""}'::jsonb
  )::json)->>'code',
  'OK',
  'update_dispo_packet_v1: empty string patch returns OK'
);

SET LOCAL ROLE postgres;
SELECT is(
  (SELECT dispo_description FROM public.deals WHERE id = 'd1145700-0000-0000-0000-000000000001'),
  NULL,
  'update_dispo_packet_v1: empty string normalized to NULL'
);
SET LOCAL ROLE authenticated;

-- 6. unknown key returns VALIDATION_ERROR
SELECT is(
  (public.update_dispo_packet_v1(
    'd1145700-0000-0000-0000-000000000001',
    '{"unknown_field":"value"}'::jsonb
  )::json)->>'code',
  'VALIDATION_ERROR',
  'update_dispo_packet_v1: unknown key returns VALIDATION_ERROR'
);

-- 7. invalid numeric returns VALIDATION_ERROR
SELECT is(
  (public.update_dispo_packet_v1(
    'd1145700-0000-0000-0000-000000000001',
    '{"dispo_asking_price":"not-a-number"}'::jsonb
  )::json)->>'code',
  'VALIDATION_ERROR',
  'update_dispo_packet_v1: invalid numeric returns VALIDATION_ERROR'
);

-- 8. invalid date returns VALIDATION_ERROR
SELECT is(
  (public.update_dispo_packet_v1(
    'd1145700-0000-0000-0000-000000000001',
    '{"dispo_closing_date":"not-a-date"}'::jsonb
  )::json)->>'code',
  'VALIDATION_ERROR',
  'update_dispo_packet_v1: invalid date returns VALIDATION_ERROR'
);

-- 9. non-HTTPS URL returns VALIDATION_ERROR
SELECT is(
  (public.update_dispo_packet_v1(
    'd1145700-0000-0000-0000-000000000001',
    '{"dispo_media_url":"http://example.com/video"}'::jsonb
  )::json)->>'code',
  'VALIDATION_ERROR',
  'update_dispo_packet_v1: non-HTTPS URL returns VALIDATION_ERROR'
);

-- 10. bare https:// returns VALIDATION_ERROR
SELECT is(
  (public.update_dispo_packet_v1(
    'd1145700-0000-0000-0000-000000000001',
    '{"dispo_media_url":"https://"}'::jsonb
  )::json)->>'code',
  'VALIDATION_ERROR',
  'update_dispo_packet_v1: bare https:// returns VALIDATION_ERROR'
);

-- 11. valid https:// URL accepted
SELECT is(
  (public.update_dispo_packet_v1(
    'd1145700-0000-0000-0000-000000000001',
    '{"dispo_media_url":"https://example.com/video.mp4"}'::jsonb
  )::json)->>'code',
  'OK',
  'update_dispo_packet_v1: valid https:// URL accepted'
);

-- 12. cross-tenant returns NOT_FOUND
SELECT is(
  (public.update_dispo_packet_v1(
    'd1145700-0000-0000-0000-000000000099',
    '{"dispo_description":"cross tenant"}'::jsonb
  )::json)->>'code',
  'NOT_FOUND',
  'update_dispo_packet_v1: cross-tenant deal returns NOT_FOUND'
);

-- 13. wrong-stage returns CONFLICT
SELECT is(
  (public.update_dispo_packet_v1(
    'd1145700-0000-0000-0000-000000000003',
    '{"dispo_description":"new stage"}'::jsonb
  )::json)->>'code',
  'CONFLICT',
  'update_dispo_packet_v1: wrong-stage deal returns CONFLICT'
);

-- 14. non-member returns NOT_AUTHORIZED
SET LOCAL ROLE postgres;
INSERT INTO auth.users (id, email) VALUES ('a1145700-0000-0000-0000-000000000088', 'nomember@test.com') ON CONFLICT DO NOTHING;
SELECT set_config('request.jwt.claims',
  '{"sub":"a1145700-0000-0000-0000-000000000088","role":"authenticated","tenant_id":"b1145700-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.update_dispo_packet_v1(
    'd1145700-0000-0000-0000-000000000001',
    '{"dispo_description":"blocked"}'::jsonb
  )::json)->>'code',
  'NOT_AUTHORIZED',
  'update_dispo_packet_v1: non-member returns NOT_AUTHORIZED'
);

-- Seed packet fields for public lookup tests
SET LOCAL ROLE postgres;
UPDATE public.deals SET
  dispo_asking_price = 250000,
  dispo_intersection = 'Main & Oak',
  dispo_description = 'Great deal',
  dispo_market_value_estimate = 300000,
  dispo_below_market_override = NULL
WHERE id = 'd1145700-0000-0000-0000-000000000001';

SET LOCAL ROLE anon;

-- 15. public lookup valid token returns OK
SELECT is(
  (public.lookup_share_token_public_v1(
    'shr_b7000000000000000000000000000000000000000000000000000000000000aa'
  )::json)->>'code',
  'OK',
  'lookup_share_token_public_v1: anon valid token returns OK'
);

-- 16. returns dispo_intersection
SELECT is(
  (public.lookup_share_token_public_v1(
    'shr_b7000000000000000000000000000000000000000000000000000000000000aa'
  )::json)->'data'->>'dispo_intersection',
  'Main & Oak',
  'lookup_share_token_public_v1: returns dispo_intersection'
);

-- 17. derives dispo_below_market_value (300000 - 250000 = 50000)
SELECT is(
  (public.lookup_share_token_public_v1(
    'shr_b7000000000000000000000000000000000000000000000000000000000000aa'
  )::json)->'data'->>'dispo_below_market_value',
  '50000',
  'lookup_share_token_public_v1: derives dispo_below_market_value'
);

-- 18. override takes precedence
SET LOCAL ROLE postgres;
UPDATE public.deals SET dispo_below_market_override = 75000
WHERE id = 'd1145700-0000-0000-0000-000000000001';
SET LOCAL ROLE anon;

SELECT is(
  (public.lookup_share_token_public_v1(
    'shr_b7000000000000000000000000000000000000000000000000000000000000aa'
  )::json)->'data'->>'dispo_below_market_value',
  '75000',
  'lookup_share_token_public_v1: override takes precedence over derived value'
);

-- 19. does NOT return exact address
SELECT is(
  (public.lookup_share_token_public_v1(
    'shr_b7000000000000000000000000000000000000000000000000000000000000aa'
  )::json)->'data'->>'address',
  NULL,
  'lookup_share_token_public_v1: does not return exact address'
);

-- 20. does not return internal/seller-sensitive fields
SELECT ok(
  NOT (
    (public.lookup_share_token_public_v1(
      'shr_b7000000000000000000000000000000000000000000000000000000000000aa'
    )::jsonb)->'data' ?| ARRAY[
      'address','deal_id','id','tenant_id','calc_version','row_version',
      'created_at','updated_at','seller_name','seller_phone','seller_email',
      'seller_pain','seller_notes','seller_timeline','next_action',
      'next_action_due','activity','notes'
    ]
  ),
  'lookup_share_token_public_v1: no internal/seller-sensitive fields in response'
);

-- 21. revoked token returns NOT_FOUND
SELECT is(
  (public.lookup_share_token_public_v1(
    'shr_b7000000000000000000000000000000000000000000000000000000000000bb'
  )::json)->>'code',
  'NOT_FOUND',
  'lookup_share_token_public_v1: revoked token returns NOT_FOUND'
);

-- 22. expired token returns NOT_FOUND
SELECT is(
  (public.lookup_share_token_public_v1(
    'shr_b7000000000000000000000000000000000000000000000000000000000000cc'
  )::json)->>'code',
  'NOT_FOUND',
  'lookup_share_token_public_v1: expired token returns NOT_FOUND'
);

-- 23. workspace-expired token returns NOT_FOUND
SELECT is(
  (public.lookup_share_token_public_v1(
    'shr_b7000000000000000000000000000000000000000000000000000000000000dd'
  )::json)->>'code',
  'NOT_FOUND',
  'lookup_share_token_public_v1: workspace-expired token returns NOT_FOUND'
);

-- 24. invalid format returns NOT_FOUND
SELECT is(
  (public.lookup_share_token_public_v1('bad_token')::json)->>'code',
  'NOT_FOUND',
  'lookup_share_token_public_v1: invalid format returns NOT_FOUND'
);

-- 25. nonexistent token returns NOT_FOUND
SELECT is(
  (public.lookup_share_token_public_v1(
    'shr_b7000000000000000000000000000000000000000000000000000000000000ff'
  )::json)->>'code',
  'NOT_FOUND',
  'lookup_share_token_public_v1: nonexistent token returns NOT_FOUND'
);

-- 26-30. Failure envelope identity -- ok=false across all cases
SELECT is((public.lookup_share_token_public_v1('bad_token')::json)->>'ok', 'false', 'envelope: invalid ok=false');
SELECT is((public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000ff')::json)->>'ok', 'false', 'envelope: nonexistent ok=false');
SELECT is((public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000bb')::json)->>'ok', 'false', 'envelope: revoked ok=false');
SELECT is((public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000cc')::json)->>'ok', 'false', 'envelope: expired ok=false');
SELECT is((public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000dd')::json)->>'ok', 'false', 'envelope: workspace-expired ok=false');

-- 31. All failure codes are identical NOT_FOUND
SELECT ok(
  (public.lookup_share_token_public_v1('bad_token')::json)->>'code' = 'NOT_FOUND'
  AND (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000ff')::json)->>'code' = 'NOT_FOUND'
  AND (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000bb')::json)->>'code' = 'NOT_FOUND'
  AND (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000cc')::json)->>'code' = 'NOT_FOUND'
  AND (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000dd')::json)->>'code' = 'NOT_FOUND',
  'envelope: all failure cases code=NOT_FOUND'
);

-- 32. All failure data fields are {}
SELECT ok(
  (public.lookup_share_token_public_v1('bad_token')::json)->>'data' = '{}'
  AND (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000ff')::json)->>'data' = '{}'
  AND (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000bb')::json)->>'data' = '{}'
  AND (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000cc')::json)->>'data' = '{}'
  AND (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000dd')::json)->>'data' = '{}',
  'envelope: all failure cases data={}'
);

-- 33. All failure error.messages are identical
SELECT ok(
  (public.lookup_share_token_public_v1('bad_token')::json)->'error'->>'message'
    = (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000ff')::json)->'error'->>'message'
  AND (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000ff')::json)->'error'->>'message'
    = (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000bb')::json)->'error'->>'message'
  AND (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000bb')::json)->'error'->>'message'
    = (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000cc')::json)->'error'->>'message'
  AND (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000cc')::json)->'error'->>'message'
    = (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000dd')::json)->'error'->>'message',
  'envelope: all failure cases error.message identical'
);

-- 34. All failure error.fields are present (jsonb key exists)
SELECT ok(
  (public.lookup_share_token_public_v1('bad_token')::jsonb)->'error' ? 'fields'
  AND (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000ff')::jsonb)->'error' ? 'fields'
  AND (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000bb')::jsonb)->'error' ? 'fields'
  AND (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000cc')::jsonb)->'error' ? 'fields'
  AND (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000dd')::jsonb)->'error' ? 'fields',
  'envelope: all failure cases error.fields present'
);

-- 35. error.fields identical across all failure cases
SELECT ok(
  (public.lookup_share_token_public_v1('bad_token')::jsonb)->'error'->'fields'
    = (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000ff')::jsonb)->'error'->'fields'
  AND (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000ff')::jsonb)->'error'->'fields'
    = (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000bb')::jsonb)->'error'->'fields'
  AND (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000bb')::jsonb)->'error'->'fields'
    = (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000cc')::jsonb)->'error'->'fields'
  AND (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000cc')::jsonb)->'error'->'fields'
    = (public.lookup_share_token_public_v1('shr_b7000000000000000000000000000000000000000000000000000000000000dd')::jsonb)->'error'->'fields',
  'envelope: all failure cases error.fields identical'
);

-- 36-37. existing lookup_share_token_v1 regression
SET LOCAL ROLE postgres;
SELECT set_config('request.jwt.claims',
  '{"sub":"a1145700-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1145700-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.lookup_share_token_v1(
    'shr_b7000000000000000000000000000000000000000000000000000000000000aa',
    'd1145700-0000-0000-0000-000000000001'
  )::json)->>'code',
  'OK',
  'lookup_share_token_v1: existing authenticated RPC still works (regression)'
);

SELECT is(
  (public.lookup_share_token_v1(
    'shr_b7000000000000000000000000000000000000000000000000000000000000aa',
    'd1145700-0000-0000-0000-000000000001'
  )::json)->'data'->>'deal_id',
  'd1145700-0000-0000-0000-000000000001',
  'lookup_share_token_v1: returns deal_id (regression)'
);

SELECT finish();
ROLLBACK;
