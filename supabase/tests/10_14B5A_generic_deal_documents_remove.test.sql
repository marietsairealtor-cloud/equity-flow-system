-- 10.14B5A: Generic Deal Document Vault + Remove Path tests
BEGIN;

SELECT plan(15);

-- Seed tenant + owner + member
SELECT public.create_active_workspace_seed_v1(
  'b1145100-0000-0000-0000-000000000001'::uuid,
  'a1145100-0000-0000-0000-000000000001'::uuid,
  'owner'
);

SELECT public.create_active_workspace_seed_v1(
  'b1145100-0000-0000-0000-000000000001'::uuid,
  'a1145100-0000-0000-0000-000000000002'::uuid,
  'member'
);

-- Seed cross-tenant
SELECT public.create_active_workspace_seed_v1(
  'b1145100-0000-0000-0000-000000000002'::uuid,
  'a1145100-0000-0000-0000-000000000099'::uuid,
  'owner'
);

-- Seed deal (under_contract)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1145100-0000-0000-0000-000000000001',
  'b1145100-0000-0000-0000-000000000001',
  1, 1, 'under_contract', '100 Vault St', now(), now()
);

-- Seed cross-tenant deal
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1145100-0000-0000-0000-000000000099',
  'b1145100-0000-0000-0000-000000000002',
  1, 1, 'under_contract', '999 Other St', now(), now()
);

-- Pre-seed two documents with known IDs for use in delete tests
SET LOCAL ROLE postgres;
INSERT INTO public.deal_documents (
  id, tenant_id, deal_id, document_type, storage_path, file_name, mime_type, file_size, uploaded_by, uploaded_at, created_at
) VALUES (
  'f1145100-0000-0000-0000-000000000010',
  'b1145100-0000-0000-0000-000000000001',
  'd1145100-0000-0000-0000-000000000001',
  'general',
  'b1145100-0000-0000-0000-000000000001/d1145100-0000-0000-0000-000000000001/documents/general/contract.pdf',
  'contract.pdf', 'application/pdf', 204800,
  'a1145100-0000-0000-0000-000000000001',
  now(), now()
),(
  'f1145100-0000-0000-0000-000000000011',
  'b1145100-0000-0000-0000-000000000001',
  'd1145100-0000-0000-0000-000000000001',
  'signed_purchase_agreement',
  'b1145100-0000-0000-0000-000000000001/d1145100-0000-0000-0000-000000000001/documents/signed_purchase_agreement/aps.pdf',
  'aps.pdf', 'application/pdf', 102400,
  'a1145100-0000-0000-0000-000000000001',
  now(), now()
),(
  'f1145100-0000-0000-0000-000000000012',
  'b1145100-0000-0000-0000-000000000001',
  'd1145100-0000-0000-0000-000000000001',
  'general',
  'b1145100-0000-0000-0000-000000000001/d1145100-0000-0000-0000-000000000001/documents/general/other.pdf',
  'other.pdf', 'application/pdf', 1024,
  'a1145100-0000-0000-0000-000000000001',
  now(), now()
);

-- Set context: tenant one owner
SELECT set_config('request.jwt.claims',
  '{"sub":"a1145100-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1145100-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- 1. attach_deal_document_v1 accepts document_type = general
SELECT is(
  (public.attach_deal_document_v1(
    'd1145100-0000-0000-0000-000000000001',
    'general',
    'b1145100-0000-0000-0000-000000000001/d1145100-0000-0000-0000-000000000001/documents/general/new.pdf',
    'new.pdf',
    'application/pdf',
    204800
  )::json)->>'code',
  'OK',
  'attach_deal_document_v1: document_type general accepted'
);

-- 2. attach_deal_document_v1 still accepts signed_purchase_agreement (backward compat)
SELECT is(
  (public.attach_deal_document_v1(
    'd1145100-0000-0000-0000-000000000001',
    'signed_purchase_agreement',
    'b1145100-0000-0000-0000-000000000001/d1145100-0000-0000-0000-000000000001/documents/signed_purchase_agreement/aps2.pdf',
    'aps2.pdf',
    'application/pdf',
    102400
  )::json)->>'code',
  'OK',
  'attach_deal_document_v1: signed_purchase_agreement still accepted (backward compat)'
);

-- 3. general path with empty filename segment returns VALIDATION_ERROR
SELECT is(
  (public.attach_deal_document_v1(
    'd1145100-0000-0000-0000-000000000001',
    'general',
    'b1145100-0000-0000-0000-000000000001/d1145100-0000-0000-0000-000000000001/documents/general/',
    'bad.pdf',
    'application/pdf',
    1024
  )::json)->>'code',
  'VALIDATION_ERROR',
  'attach_deal_document_v1: general path with empty filename segment returns VALIDATION_ERROR'
);

-- 4. cross-tenant attach returns NOT_FOUND
SELECT is(
  (public.attach_deal_document_v1(
    'd1145100-0000-0000-0000-000000000099',
    'general',
    'b1145100-0000-0000-0000-000000000001/d1145100-0000-0000-0000-000000000099/documents/general/cross.pdf',
    'cross.pdf',
    'application/pdf',
    1024
  )::json)->>'code',
  'NOT_FOUND',
  'attach_deal_document_v1: cross-tenant deal returns NOT_FOUND'
);

-- 5. list_deal_documents_v1 returns all active documents (3 pre-seeded + 2 just attached)
SELECT is(
  json_array_length(
    (public.list_deal_documents_v1('d1145100-0000-0000-0000-000000000001')::json)->'data'->'items'
  ),
  5,
  'list_deal_documents_v1: returns all active documents'
);

-- 6. delete_deal_document_v1 soft-deletes a document (known ID)
SELECT is(
  (public.delete_deal_document_v1('f1145100-0000-0000-0000-000000000010')::json)->>'code',
  'OK',
  'delete_deal_document_v1: soft-deletes document'
);

-- 7. deleted document no longer appears in list
SELECT is(
  json_array_length(
    (public.list_deal_documents_v1('d1145100-0000-0000-0000-000000000001')::json)->'data'->'items'
  ),
  4,
  'list_deal_documents_v1: excludes soft-deleted document'
);

-- 8. deleted_at and deleted_by set on soft-deleted row
SET LOCAL ROLE postgres;
SELECT ok(
  EXISTS (
    SELECT 1 FROM public.deal_documents
    WHERE id = 'f1145100-0000-0000-0000-000000000010'
      AND deleted_at IS NOT NULL
      AND deleted_by IS NOT NULL
  ),
  'deal_documents: deleted_at and deleted_by set on soft-deleted row'
);
SET LOCAL ROLE authenticated;

-- 9. delete_deal_document_v1 succeeds for another own document (known ID)
SELECT is(
  (public.delete_deal_document_v1('f1145100-0000-0000-0000-000000000011')::json)->>'code',
  'OK',
  'delete_deal_document_v1: tenant-scoped delete succeeds for own document'
);

-- 10. cross-tenant delete returns NOT_FOUND
SELECT set_config('request.jwt.claims',
  '{"sub":"a1145100-0000-0000-0000-000000000099","role":"authenticated","tenant_id":"b1145100-0000-0000-0000-000000000002"}',
  true);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.delete_deal_document_v1('f1145100-0000-0000-0000-000000000012')::json)->>'code',
  'NOT_FOUND',
  'delete_deal_document_v1: cross-tenant document returns NOT_FOUND'
);

-- 11. handoff_to_dispo_v1 succeeds without signed APS (gate removed)
SELECT set_config('request.jwt.claims',
  '{"sub":"a1145100-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1145100-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

SET LOCAL ROLE postgres;
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1145100-0000-0000-0000-000000000002',
  'b1145100-0000-0000-0000-000000000001',
  1, 1, 'under_contract', '200 No APS St', now(), now()
);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.handoff_to_dispo_v1(
    'd1145100-0000-0000-0000-000000000002',
    'a1145100-0000-0000-0000-000000000002'
  )::json)->>'code',
  'OK',
  'handoff_to_dispo_v1: succeeds without signed APS -- gate removed in 10.14B5A'
);

-- 12. non-member returns NOT_AUTHORIZED on attach
SET LOCAL ROLE postgres;
INSERT INTO auth.users (id, email) VALUES ('a1145100-0000-0000-0000-000000000088', 'nomember@test.com') ON CONFLICT DO NOTHING;
SELECT set_config('request.jwt.claims',
  '{"sub":"a1145100-0000-0000-0000-000000000088","role":"authenticated","tenant_id":"b1145100-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.attach_deal_document_v1(
    'd1145100-0000-0000-0000-000000000001',
    'general',
    'b1145100-0000-0000-0000-000000000001/d1145100-0000-0000-0000-000000000001/documents/general/blocked.pdf',
    'blocked.pdf',
    'application/pdf',
    1024
  )::json)->>'code',
  'NOT_AUTHORIZED',
  'attach_deal_document_v1: non-member returns NOT_AUTHORIZED'
);

-- 13. non-member returns NOT_AUTHORIZED on list
SELECT is(
  (public.list_deal_documents_v1('d1145100-0000-0000-0000-000000000001')::json)->>'code',
  'NOT_AUTHORIZED',
  'list_deal_documents_v1: non-member returns NOT_AUTHORIZED'
);

-- 14. non-member returns NOT_AUTHORIZED on delete
SELECT is(
  (public.delete_deal_document_v1('f1145100-0000-0000-0000-000000000012')::json)->>'code',
  'NOT_AUTHORIZED',
  'delete_deal_document_v1: non-member returns NOT_AUTHORIZED'
);

-- 15. direct table access still blocked
SELECT set_config('request.jwt.claims',
  '{"sub":"a1145100-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1145100-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

SELECT throws_ok(
  $tap$ SELECT COUNT(*) FROM public.deal_documents $tap$,
  '42501',
  NULL,
  'deal_documents: direct table access blocked for authenticated role'
);

SELECT finish();
ROLLBACK;