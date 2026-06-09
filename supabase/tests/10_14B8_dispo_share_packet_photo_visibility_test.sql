-- 10.14B8 — Dispo Backend — Share Packet Photo Visibility
-- Paired migrations: 20260608000001 + 20260608000002 + 20260608000003
-- Test count: 42

BEGIN;

SELECT plan(42);

-- ============================================================
-- Seed: tenant 1 (primary)
-- ============================================================
INSERT INTO public.tenants (id, name)
VALUES ('a1000000-0000-0000-0000-000000000001', 'T1');

INSERT INTO auth.users (id, email)
VALUES ('b1000000-0000-0000-0000-000000000001', 'member1@t1.test');

INSERT INTO public.user_profiles (id, current_tenant_id)
VALUES ('b1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001');

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES (gen_random_uuid(), 'a1000000-0000-0000-0000-000000000001',
        'b1000000-0000-0000-0000-000000000001', 'member');

INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
VALUES ('a1000000-0000-0000-0000-000000000001', 'active', now() + interval '30 days');

INSERT INTO public.deals (id, tenant_id, stage, address)
VALUES ('d1000000-0000-0000-0000-000000000001',
        'a1000000-0000-0000-0000-000000000001', 'dispo', '123 Test St');

INSERT INTO public.deal_media (id, tenant_id, deal_id, storage_path, sort_order, uploaded_by)
VALUES
  ('e1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001',
   'd1000000-0000-0000-0000-000000000001',
   'a1000000-0000-0000-0000-000000000001/d1000000-0000-0000-0000-000000000001/e1000000.jpg',
   1, 'b1000000-0000-0000-0000-000000000001'),
  ('e2000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001',
   'd1000000-0000-0000-0000-000000000001',
   'a1000000-0000-0000-0000-000000000001/d1000000-0000-0000-0000-000000000001/e2000000.jpg',
   2, 'b1000000-0000-0000-0000-000000000001');

-- Share token: shr_ + 64 lowercase hex chars = valid 68-char token
INSERT INTO public.share_tokens
  (id, tenant_id, deal_id, token_hash, expires_at)
VALUES
  ('f1000000-0000-0000-0000-000000000001',
   'a1000000-0000-0000-0000-000000000001',
   'd1000000-0000-0000-0000-000000000001',
   extensions.digest('shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'sha256'),
   now() + interval '1 day');

-- ============================================================
-- Seed: tenant 2 (cross-tenant isolation)
-- ============================================================
INSERT INTO public.tenants (id, name)
VALUES ('a2000000-0000-0000-0000-000000000002', 'T2');

INSERT INTO auth.users (id, email)
VALUES ('b2000000-0000-0000-0000-000000000002', 'member2@t2.test');

INSERT INTO public.user_profiles (id, current_tenant_id)
VALUES ('b2000000-0000-0000-0000-000000000002', 'a2000000-0000-0000-0000-000000000002');

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES (gen_random_uuid(), 'a2000000-0000-0000-0000-000000000002',
        'b2000000-0000-0000-0000-000000000002', 'member');

INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
VALUES ('a2000000-0000-0000-0000-000000000002', 'active', now() + interval '30 days');

-- ============================================================
-- TEST 1-3: Schema columns present
-- ============================================================
SELECT has_column('public', 'deal_media', 'is_dispo_approved',
  'deal_media.is_dispo_approved column exists');

SELECT has_column('public', 'deal_media', 'dispo_approved_at',
  'deal_media.dispo_approved_at column exists');

SELECT has_column('public', 'deal_media', 'dispo_approved_by',
  'deal_media.dispo_approved_by column exists');

-- TEST 4: Existing media defaults to is_dispo_approved = false
SELECT is(
  (SELECT is_dispo_approved FROM public.deal_media
    WHERE id = 'e1000000-0000-0000-0000-000000000001'::uuid),
  false,
  'existing media defaults to is_dispo_approved = false'
);

-- ============================================================
-- TEST 5-6: Null input validation (no JWT context required)
-- ============================================================
SELECT is(
  (SELECT public.update_deal_media_dispo_approval_v1(NULL, true) ->> 'code'),
  'VALIDATION_ERROR',
  'null p_media_id returns VALIDATION_ERROR'
);

SELECT is(
  (SELECT public.update_deal_media_dispo_approval_v1(
    'e1000000-0000-0000-0000-000000000001'::uuid, NULL) ->> 'code'),
  'VALIDATION_ERROR',
  'null p_is_dispo_approved returns VALIDATION_ERROR'
);

-- ============================================================
-- Set JWT context: tenant 1 member (approved pattern)
-- ============================================================
SET LOCAL request.jwt.claim.sub       = 'b1000000-0000-0000-0000-000000000001';
SET LOCAL request.jwt.claim.role      = 'authenticated';
SET LOCAL request.jwt.claim.tenant_id = 'a1000000-0000-0000-0000-000000000001';
SELECT set_config('request.jwt.claims',
  '{"sub":"b1000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"a1000000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- ============================================================
-- TEST 7: Member can mark media as share-approved (ok = true)
-- ============================================================
SELECT ok(
  (SELECT (public.update_deal_media_dispo_approval_v1(
    'e1000000-0000-0000-0000-000000000001'::uuid, true) ->> 'ok')::boolean),
  'member can mark media as share-approved'
);

-- TEST 8: is_dispo_approved = true after approval
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT is_dispo_approved FROM public.deal_media
    WHERE id = 'e1000000-0000-0000-0000-000000000001'::uuid),
  true,
  'approved media sets is_dispo_approved = true'
);

-- TEST 9: dispo_approved_at is set (not null) after approval
SELECT isnt(
  (SELECT dispo_approved_at FROM public.deal_media
    WHERE id = 'e1000000-0000-0000-0000-000000000001'::uuid),
  NULL,
  'approved media sets dispo_approved_at (not null)'
);

-- TEST 10: dispo_approved_by = auth.uid()
SELECT is(
  (SELECT dispo_approved_by FROM public.deal_media
    WHERE id = 'e1000000-0000-0000-0000-000000000001'::uuid),
  'b1000000-0000-0000-0000-000000000001'::uuid,
  'approved media sets dispo_approved_by = auth.uid()'
);
SET LOCAL ROLE authenticated;

-- TEST 11: Member can remove media from share packet (ok = true)
SELECT ok(
  (SELECT (public.update_deal_media_dispo_approval_v1(
    'e1000000-0000-0000-0000-000000000001'::uuid, false) ->> 'ok')::boolean),
  'member can remove media from share packet'
);

-- TEST 12: is_dispo_approved = false after removal
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT is_dispo_approved FROM public.deal_media
    WHERE id = 'e1000000-0000-0000-0000-000000000001'::uuid),
  false,
  'removing approval sets is_dispo_approved = false'
);

-- TEST 13: dispo_approved_at cleared after removal
SELECT is(
  (SELECT dispo_approved_at FROM public.deal_media
    WHERE id = 'e1000000-0000-0000-0000-000000000001'::uuid),
  NULL,
  'removing approval clears dispo_approved_at'
);

-- TEST 14: dispo_approved_by cleared after removal
SELECT is(
  (SELECT dispo_approved_by FROM public.deal_media
    WHERE id = 'e1000000-0000-0000-0000-000000000001'::uuid),
  NULL,
  'removing approval clears dispo_approved_by'
);
SET LOCAL ROLE authenticated;

-- ============================================================
-- Re-approve e1 for public lookup tests; e2 stays unapproved
-- (Use governed RPC — direct UPDATE blocked under authenticated)
-- ============================================================
SELECT public.update_deal_media_dispo_approval_v1(
  'e1000000-0000-0000-0000-000000000001'::uuid,
  true
);

-- ============================================================
-- Public buyer context: anon, no tenant claims
-- ============================================================
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', true);

-- TEST 15: lookup returns ok = true for valid token
SELECT ok(
  (SELECT (public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  ) ->> 'ok')::boolean),
  'lookup_share_token_public_v1 returns ok=true for valid token (as anon)'
);

-- TEST 16: data.media is present (not null)
SELECT ok(
  (SELECT public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  ) -> 'data' -> 'media') IS NOT NULL,
  'lookup_share_token_public_v1 returns data.media (not null)'
);

-- TEST 17: approved media (e1) appears in data.media
SELECT ok(
  EXISTS(
    SELECT 1
    FROM jsonb_array_elements(
      public.lookup_share_token_public_v1(
        'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      )::jsonb -> 'data' -> 'media'
    ) m
    WHERE m ->> 'media_id' = 'e1000000-0000-0000-0000-000000000001'
  ),
  'approved media appears in data.media'
);

-- TEST 18: unapproved media (e2) NOT in data.media
SELECT is(
  (SELECT NOT EXISTS(
    SELECT 1
    FROM jsonb_array_elements(
      public.lookup_share_token_public_v1(
        'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      )::jsonb -> 'data' -> 'media'
    ) m
    WHERE m ->> 'media_id' = 'e2000000-0000-0000-0000-000000000001'
  )),
  true,
  'unapproved media is not returned in data.media'
);

-- ============================================================
-- TEST 19-27: Sensitive data fields absent from public response
-- ============================================================
SELECT is(
  (SELECT (public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  )::jsonb -> 'data') ? 'address'),
  false, 'data does not expose address');

SELECT is(
  (SELECT (public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  )::jsonb -> 'data') ? 'deal_id'),
  false, 'data does not expose deal_id');

SELECT is(
  (SELECT (public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  )::jsonb -> 'data') ? 'tenant_id'),
  false, 'data does not expose tenant_id');

SELECT is(
  (SELECT (public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  )::jsonb -> 'data') ? 'seller_name'),
  false, 'data does not expose seller_name');

SELECT is(
  (SELECT (public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  )::jsonb -> 'data') ? 'seller_phone'),
  false, 'data does not expose seller_phone');

SELECT is(
  (SELECT (public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  )::jsonb -> 'data') ? 'seller_email'),
  false, 'data does not expose seller_email');

SELECT is(
  (SELECT (public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  )::jsonb -> 'data') ? 'seller_pain'),
  false, 'data does not expose seller_pain');

SELECT is(
  (SELECT (public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  )::jsonb -> 'data') ? 'seller_notes'),
  false, 'data does not expose seller_notes');

SELECT is(
  (SELECT (public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  )::jsonb -> 'data') ? 'notes'),
  false, 'data does not expose notes');

SELECT is(
  (SELECT (public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  )::jsonb -> 'data') ? 'activity'),
  false, 'data does not expose activity');

SELECT is(
  (SELECT (public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  )::jsonb -> 'data') ? 'internal_notes'),
  false, 'data does not expose internal_notes');

-- ============================================================
-- TEST 28-33: Internal media item fields absent from each media element
-- ============================================================
SELECT is(
  (SELECT m ? 'tenant_id'
     FROM jsonb_array_elements(
       public.lookup_share_token_public_v1(
         'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
       )::jsonb -> 'data' -> 'media'
     ) m
    WHERE m ->> 'media_id' = 'e1000000-0000-0000-0000-000000000001'
    LIMIT 1),
  false, 'media item does not expose tenant_id');

SELECT is(
  (SELECT m ? 'deal_id'
     FROM jsonb_array_elements(
       public.lookup_share_token_public_v1(
         'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
       )::jsonb -> 'data' -> 'media'
     ) m
    WHERE m ->> 'media_id' = 'e1000000-0000-0000-0000-000000000001'
    LIMIT 1),
  false, 'media item does not expose deal_id');

SELECT is(
  (SELECT m ? 'uploaded_by'
     FROM jsonb_array_elements(
       public.lookup_share_token_public_v1(
         'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
       )::jsonb -> 'data' -> 'media'
     ) m
    WHERE m ->> 'media_id' = 'e1000000-0000-0000-0000-000000000001'
    LIMIT 1),
  false, 'media item does not expose uploaded_by');

SELECT is(
  (SELECT m ? 'is_dispo_approved'
     FROM jsonb_array_elements(
       public.lookup_share_token_public_v1(
         'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
       )::jsonb -> 'data' -> 'media'
     ) m
    WHERE m ->> 'media_id' = 'e1000000-0000-0000-0000-000000000001'
    LIMIT 1),
  false, 'media item does not expose is_dispo_approved');

SELECT is(
  (SELECT m ? 'dispo_approved_at'
     FROM jsonb_array_elements(
       public.lookup_share_token_public_v1(
         'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
       )::jsonb -> 'data' -> 'media'
     ) m
    WHERE m ->> 'media_id' = 'e1000000-0000-0000-0000-000000000001'
    LIMIT 1),
  false, 'media item does not expose dispo_approved_at');

SELECT is(
  (SELECT m ? 'dispo_approved_by'
     FROM jsonb_array_elements(
       public.lookup_share_token_public_v1(
         'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
       )::jsonb -> 'data' -> 'media'
     ) m
    WHERE m ->> 'media_id' = 'e1000000-0000-0000-0000-000000000001'
    LIMIT 1),
  false, 'media item does not expose dispo_approved_by');

-- ============================================================
-- TEST 34: Cross-tenant approval returns NOT_FOUND
-- ============================================================
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub       = 'b2000000-0000-0000-0000-000000000002';
SET LOCAL request.jwt.claim.role      = 'authenticated';
SET LOCAL request.jwt.claim.tenant_id = 'a2000000-0000-0000-0000-000000000002';
SELECT set_config('request.jwt.claims',
  '{"sub":"b2000000-0000-0000-0000-000000000002","role":"authenticated","tenant_id":"a2000000-0000-0000-0000-000000000002"}',
  true);

SELECT is(
  (SELECT public.update_deal_media_dispo_approval_v1(
    'e1000000-0000-0000-0000-000000000001'::uuid, true) ->> 'code'),
  'NOT_FOUND',
  'cross-tenant approval attempt returns NOT_FOUND'
);

-- ============================================================
-- TEST 35: Non-member (viewer) returns NOT_AUTHORIZED
-- ============================================================
SET LOCAL request.jwt.claim.sub       = 'b1000000-0000-0000-0000-000000000001';
SET LOCAL request.jwt.claim.role      = 'authenticated';
SET LOCAL request.jwt.claim.tenant_id = 'a1000000-0000-0000-0000-000000000001';
SELECT set_config('request.jwt.claims',
  '{"sub":"b1000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"a1000000-0000-0000-0000-000000000001"}',
  true);

SET LOCAL ROLE postgres;
DELETE FROM public.tenant_memberships
 WHERE tenant_id = 'a1000000-0000-0000-0000-000000000001'::uuid
   AND user_id   = 'b1000000-0000-0000-0000-000000000001'::uuid;
SET LOCAL ROLE authenticated;

SELECT is(
  (SELECT public.update_deal_media_dispo_approval_v1(
    'e1000000-0000-0000-0000-000000000001'::uuid, true) ->> 'code'),
  'NOT_AUTHORIZED',
  'non-member returns NOT_AUTHORIZED'
);

SET LOCAL ROLE postgres;
INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES (gen_random_uuid(), 'a1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'member');
SET LOCAL ROLE authenticated;

-- ============================================================
-- TEST 36: Workspace write-locked returns WORKSPACE_NOT_WRITABLE
-- ============================================================
SET LOCAL ROLE postgres;
UPDATE public.tenant_subscriptions
   SET status = 'canceled'
 WHERE tenant_id = 'a1000000-0000-0000-0000-000000000001'::uuid;
SET LOCAL ROLE authenticated;

SELECT is(
  (SELECT public.update_deal_media_dispo_approval_v1(
    'e1000000-0000-0000-0000-000000000001'::uuid, true) ->> 'code'),
  'WORKSPACE_NOT_WRITABLE',
  'workspace write-locked tenant returns WORKSPACE_NOT_WRITABLE'
);

SET LOCAL ROLE postgres;
UPDATE public.tenant_subscriptions
   SET status = 'active'
 WHERE tenant_id = 'a1000000-0000-0000-0000-000000000001'::uuid;
SET LOCAL ROLE authenticated;

-- ============================================================
-- TEST 37-38: lookup_share_token_v1 authenticated contract unchanged
-- ============================================================
SELECT ok(
  (SELECT (public.lookup_share_token_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'd1000000-0000-0000-0000-000000000001'::uuid
  ) ->> 'ok')::boolean),
  'lookup_share_token_v1 still returns ok=true for valid token (contract unchanged)'
);

SELECT is(
  (SELECT public.lookup_share_token_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'd1000000-0000-0000-0000-000000000001'::uuid
  ) ->> 'code'),
  'OK',
  'lookup_share_token_v1 code=OK (contract unchanged)'
);

-- TEST 39: invalid media ID returns NOT_FOUND
SELECT is(
  (SELECT public.update_deal_media_dispo_approval_v1(
    '00000000-0000-0000-0000-000000000000'::uuid, true) ->> 'code'),
  'NOT_FOUND',
  'invalid media ID returns NOT_FOUND'
);

-- ============================================================
-- TEST 41 (formerly last) shifted; TEST 42 NEW:
-- approved media with mismatched tenant_id not returned by public lookup
-- Seed: an approved deal_media row belonging to tenant 2's deal,
-- but whose deal_id matches tenant 1's deal (simulate orphan/mismatch).
-- The public lookup token resolves to tenant 1; dm.tenant_id = T2 must be excluded.
-- ============================================================
SET LOCAL ROLE postgres;
INSERT INTO public.deals (id, tenant_id, stage)
VALUES ('d2000000-0000-0000-0000-000000000002',
        'a2000000-0000-0000-0000-000000000002', 'dispo');

-- Media row: correct deal_id for T1's deal but wrong tenant_id (T2)
INSERT INTO public.deal_media (id, tenant_id, deal_id, storage_path, sort_order, uploaded_by)
VALUES (
  'e3000000-0000-0000-0000-000000000003',
  'a2000000-0000-0000-0000-000000000002',
  'd1000000-0000-0000-0000-000000000001',
  'a2000000-0000-0000-0000-000000000002/d1000000-0000-0000-0000-000000000001/e3000000.jpg',
  3, 'b2000000-0000-0000-0000-000000000002'
);

-- Mark it approved (bypass RPC — direct write as postgres)
UPDATE public.deal_media
   SET is_dispo_approved = true,
       dispo_approved_at = now(),
       dispo_approved_by = 'b2000000-0000-0000-0000-000000000002'::uuid
 WHERE id = 'e3000000-0000-0000-0000-000000000003'::uuid;

-- Switch to anon for public lookup
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', true);

-- TEST 42: mismatched-tenant media must not appear in public lookup response
SELECT is(
  (SELECT NOT EXISTS(
    SELECT 1
    FROM jsonb_array_elements(
      public.lookup_share_token_public_v1('shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')::jsonb -> 'data' -> 'media'
    ) m
    WHERE m ->> 'media_id' = 'e3000000-0000-0000-0000-000000000003'
  )),
  true,
  'approved media with mismatched tenant_id is not returned by public lookup'
);

SELECT finish();
ROLLBACK;
