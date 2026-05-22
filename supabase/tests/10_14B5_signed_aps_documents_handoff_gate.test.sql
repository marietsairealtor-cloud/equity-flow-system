-- 10.14B5: Acquisition Backend -- Signed APS Documents + Handoff Gate tests
BEGIN;

SELECT plan(18);

-- Seed tenant + owner + member
SELECT public.create_active_workspace_seed_v1(
  'b1145000-0000-0000-0000-000000000001'::uuid,
  'a1145000-0000-0000-0000-000000000001'::uuid,
  'owner'
);

SELECT public.create_active_workspace_seed_v1(
  'b1145000-0000-0000-0000-000000000001'::uuid,
  'a1145000-0000-0000-0000-000000000002'::uuid,
  'member'
);

-- Seed cross-tenant
SELECT public.create_active_workspace_seed_v1(
  'b1145000-0000-0000-0000-000000000002'::uuid,
  'a1145000-0000-0000-0000-000000000099'::uuid,
  'owner'
);

-- Seed deal for tenant one (under_contract -- ready for handoff)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1145000-0000-0000-0000-000000000001',
  'b1145000-0000-0000-0000-000000000001',
  1, 1, 'under_contract', '123 APS St', now(), now()
);

-- Seed deal two for tenant one (dispo -- grandfathered)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1145000-0000-0000-0000-000000000002',
  'b1145000-0000-0000-0000-000000000001',
  1, 1, 'dispo', '456 Dispo St', now(), now()
);

-- Seed real cross-tenant deal (tenant two)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1145000-0000-0000-0000-000000000099',
  'b1145000-0000-0000-0000-000000000002',
  1, 1, 'under_contract', '999 Other Tenant St', now(), now()
);

-- Set context: tenant one owner
SELECT set_config('request.jwt.claims',
  '{"sub":"a1145000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1145000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- 1. attach_deal_document_v1 accepts signed_purchase_agreement
SELECT is(
  (public.attach_deal_document_v1(
    'd1145000-0000-0000-0000-000000000001',
    'signed_purchase_agreement',
    'b1145000-0000-0000-0000-000000000001/d1145000-0000-0000-0000-000000000001/documents/signed_purchase_agreement/aps.pdf',
    'aps.pdf',
    'application/pdf',
    102400
  )::json)->>'code',
  'OK',
  'attach_deal_document_v1: signed_purchase_agreement accepted'
);

-- 2. list_deal_documents_v1 returns OK
SELECT is(
  (public.list_deal_documents_v1('d1145000-0000-0000-0000-000000000001')::json)->>'code',
  'OK',
  'list_deal_documents_v1: returns OK'
);

-- 3. list_deal_documents_v1 returns the attached document
SELECT ok(
  EXISTS (
    SELECT 1
    FROM json_array_elements(
      (public.list_deal_documents_v1('d1145000-0000-0000-0000-000000000001')::json)->'data'->'items'
    ) AS item
    WHERE item->>'document_type' = 'signed_purchase_agreement'
      AND item->>'file_name' = 'aps.pdf'
  ),
  'list_deal_documents_v1: returns attached APS document'
);

-- 4. list_deal_documents_v1 metadata only -- no content field
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(
      (public.list_deal_documents_v1('d1145000-0000-0000-0000-000000000001')::jsonb)->'data'->'items'
    ) AS item
    WHERE item ? 'content'
  ),
  'list_deal_documents_v1: metadata only -- no content field in items'
);

-- 5. invalid document_type returns VALIDATION_ERROR
SELECT is(
  (public.attach_deal_document_v1(
    'd1145000-0000-0000-0000-000000000001',
    'random_doc',
    'b1145000-0000-0000-0000-000000000001/d1145000-0000-0000-0000-000000000001/documents/random_doc/file.pdf',
    'file.pdf',
    'application/pdf',
    102400
  )::json)->>'code',
  'VALIDATION_ERROR',
  'attach_deal_document_v1: invalid document_type returns VALIDATION_ERROR'
);

-- 6. unsafe storage_path (path traversal) returns VALIDATION_ERROR
SELECT is(
  (public.attach_deal_document_v1(
    'd1145000-0000-0000-0000-000000000001',
    'signed_purchase_agreement',
    'b1145000-0000-0000-0000-000000000001/d1145000-0000-0000-0000-000000000001/documents/signed_purchase_agreement/../../../etc/passwd',
    'evil.pdf',
    'application/pdf',
    102400
  )::json)->>'code',
  'VALIDATION_ERROR',
  'attach_deal_document_v1: path traversal returns VALIDATION_ERROR'
);

-- 7. storage_path with no filename after prefix returns VALIDATION_ERROR
SELECT is(
  (public.attach_deal_document_v1(
    'd1145000-0000-0000-0000-000000000001',
    'signed_purchase_agreement',
    'b1145000-0000-0000-0000-000000000001/d1145000-0000-0000-0000-000000000001/documents/signed_purchase_agreement/',
    'aps.pdf',
    'application/pdf',
    102400
  )::json)->>'code',
  'VALIDATION_ERROR',
  'attach_deal_document_v1: empty filename segment returns VALIDATION_ERROR'
);

-- 8. cross-tenant attach returns NOT_FOUND
-- tenant-one context, tenant-two deal -- deal is not visible to tenant one
SELECT is(
  (public.attach_deal_document_v1(
    'd1145000-0000-0000-0000-000000000099',
    'signed_purchase_agreement',
    'b1145000-0000-0000-0000-000000000001/d1145000-0000-0000-0000-000000000099/documents/signed_purchase_agreement/aps.pdf',
    'aps.pdf',
    'application/pdf',
    102400
  )::json)->>'code',
  'NOT_FOUND',
  'attach_deal_document_v1: cross-tenant deal returns NOT_FOUND'
);

-- 9. missing deal returns NOT_FOUND
SELECT is(
  (public.attach_deal_document_v1(
    'f9990000-0000-0000-0000-000000000001',
    'signed_purchase_agreement',
    'b1145000-0000-0000-0000-000000000001/f9990000-0000-0000-0000-000000000001/documents/signed_purchase_agreement/aps.pdf',
    'aps.pdf',
    'application/pdf',
    102400
  )::json)->>'code',
  'NOT_FOUND',
  'attach_deal_document_v1: missing deal returns NOT_FOUND'
);

-- 10. handoff_to_dispo_v1 succeeds when signed APS exists
SELECT is(
  (public.handoff_to_dispo_v1(
    'd1145000-0000-0000-0000-000000000001',
    'a1145000-0000-0000-0000-000000000002'
  )::json)->>'code',
  'OK',
  'handoff_to_dispo_v1: succeeds when signed APS exists'
);

-- 11. handoff_to_dispo_v1 rejects when signed APS is missing
SET LOCAL ROLE postgres;
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1145000-0000-0000-0000-000000000003',
  'b1145000-0000-0000-0000-000000000001',
  1, 1, 'under_contract', '789 No APS St', now(), now()
);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.handoff_to_dispo_v1(
    'd1145000-0000-0000-0000-000000000003',
    'a1145000-0000-0000-0000-000000000002'
  )::json)->>'code',
  'OK',
  'handoff_to_dispo_v1: succeeds without signed APS -- gate removed in 10.14B5A'
);

-- 12. existing dispo deal not retroactively blocked
SELECT is(
  (public.list_deal_documents_v1('d1145000-0000-0000-0000-000000000002')::json)->>'code',
  'OK',
  'existing dispo deal: list_deal_documents_v1 not blocked'
);

-- 13. workspace write-lock: attach blocked when expired
SET LOCAL ROLE postgres;
UPDATE public.tenant_subscriptions
SET status = 'canceled', current_period_end = now() - interval '70 days'
WHERE tenant_id = 'b1145000-0000-0000-0000-000000000001';
SET LOCAL ROLE authenticated;

SELECT is(
  (public.attach_deal_document_v1(
    'd1145000-0000-0000-0000-000000000003',
    'signed_purchase_agreement',
    'b1145000-0000-0000-0000-000000000001/d1145000-0000-0000-0000-000000000003/documents/signed_purchase_agreement/aps.pdf',
    'aps.pdf',
    'application/pdf',
    102400
  )::json)->>'code',
  'WORKSPACE_NOT_WRITABLE',
  'attach_deal_document_v1: expired workspace returns WORKSPACE_NOT_WRITABLE'
);

-- Restore subscription
SET LOCAL ROLE postgres;
UPDATE public.tenant_subscriptions
SET status = 'active', current_period_end = now() + interval '30 days'
WHERE tenant_id = 'b1145000-0000-0000-0000-000000000001';

-- 14. non-member returns NOT_AUTHORIZED on attach
-- Seed a user with no tenant-one membership
SET LOCAL ROLE postgres;
INSERT INTO auth.users (id, email) VALUES ('a1145000-0000-0000-0000-000000000088', 'nomember@test.com') ON CONFLICT DO NOTHING;
SELECT set_config('request.jwt.claims',
  '{"sub":"a1145000-0000-0000-0000-000000000088","role":"authenticated","tenant_id":"b1145000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.attach_deal_document_v1(
    'd1145000-0000-0000-0000-000000000001',
    'signed_purchase_agreement',
    'b1145000-0000-0000-0000-000000000001/d1145000-0000-0000-0000-000000000001/documents/signed_purchase_agreement/aps2.pdf',
    'aps2.pdf',
    'application/pdf',
    102400
  )::json)->>'code',
  'NOT_AUTHORIZED',
  'attach_deal_document_v1: non-member returns NOT_AUTHORIZED'
);

-- 15. non-member returns NOT_AUTHORIZED on list
SELECT is(
  (public.list_deal_documents_v1('d1145000-0000-0000-0000-000000000001')::json)->>'code',
  'NOT_AUTHORIZED',
  'list_deal_documents_v1: non-member returns NOT_AUTHORIZED'
);

-- 16. non-member returns NOT_AUTHORIZED on handoff
SELECT is(
  (public.handoff_to_dispo_v1(
    'd1145000-0000-0000-0000-000000000003',
    'a1145000-0000-0000-0000-000000000002'
  )::json)->>'code',
  'NOT_AUTHORIZED',
  'handoff_to_dispo_v1: non-member returns NOT_AUTHORIZED'
);

-- 17. direct table access blocked for authenticated role
SELECT throws_ok(
  $tap$ SELECT COUNT(*) FROM public.deal_documents $tap$,
  '42501',
  NULL,
  'deal_documents: direct table access blocked for authenticated role'
);

-- 18. storage_path with wrong tenant prefix returns VALIDATION_ERROR
SELECT set_config('request.jwt.claims',
  '{"sub":"a1145000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1145000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;


SELECT is(
  (public.attach_deal_document_v1(
    'd1145000-0000-0000-0000-000000000001',
    'signed_purchase_agreement',
    'wrongtenant/d1145000-0000-0000-0000-000000000001/documents/signed_purchase_agreement/aps.pdf',
    'aps.pdf',
    'application/pdf',
    102400
  )::json)->>'code',
  'VALIDATION_ERROR',
  'attach_deal_document_v1: wrong tenant prefix returns VALIDATION_ERROR'
);

SELECT finish();
ROLLBACK;
