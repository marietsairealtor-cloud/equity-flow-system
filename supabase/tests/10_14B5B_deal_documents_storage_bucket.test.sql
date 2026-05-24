-- 10.14B5B: Deal Documents Storage Bucket + RLS Policies tests
-- Local pgTAP scope: structural bucket assertions + negative RLS behavioral assertions only.
-- Positive same-tenant INSERT/SELECT proof is environment-split to remote/live storage smoke
-- per QA ruling 2026-05-24 (current_tenant_id() not readable from storage RLS in pgTAP context).
BEGIN;

SELECT plan(9);

-- Seed tenant + owner for behavioral tests
SELECT public.create_active_workspace_seed_v1(
  'b1145200-0000-0000-0000-000000000001'::uuid,
  'a1145200-0000-0000-0000-000000000001'::uuid,
  'owner'
);

-- Seed cross-tenant
SELECT public.create_active_workspace_seed_v1(
  'b1145200-0000-0000-0000-000000000002'::uuid,
  'a1145200-0000-0000-0000-000000000099'::uuid,
  'owner'
);

-- 1. deal-documents bucket exists
SELECT is(
  (SELECT name FROM storage.buckets WHERE id = 'deal-documents'),
  'deal-documents',
  'deal-documents bucket exists'
);

-- 2. bucket is private
SELECT is(
  (SELECT public FROM storage.buckets WHERE id = 'deal-documents'),
  false,
  'deal-documents bucket is private'
);

-- 3. bucket file size limit is 10 MB
SELECT is(
  (SELECT file_size_limit FROM storage.buckets WHERE id = 'deal-documents'),
  10485760::bigint,
  'deal-documents bucket file size limit is 10 MB'
);

-- 4. bucket MIME allowlist includes application/pdf
SELECT ok(
  (SELECT allowed_mime_types FROM storage.buckets WHERE id = 'deal-documents') @> ARRAY['application/pdf'],
  'deal-documents bucket MIME allowlist includes application/pdf'
);

-- 5. bucket MIME allowlist includes Word document type
SELECT ok(
  (SELECT allowed_mime_types FROM storage.buckets WHERE id = 'deal-documents') @> ARRAY['application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
  'deal-documents bucket MIME allowlist includes Word document type'
);

-- Seed one valid object as postgres for anon SELECT test
SET LOCAL ROLE postgres;
INSERT INTO storage.objects (id, bucket_id, name, owner, created_at, updated_at, last_accessed_at, metadata)
VALUES (
  'f1145200-0000-0000-0000-000000000001'::uuid,
  'deal-documents',
  'b1145200-0000-0000-0000-000000000001/d1145200-0000-0000-0000-000000000001/documents/general/test.pdf',
  'a1145200-0000-0000-0000-000000000001'::uuid,
  now(), now(), now(), '{}'
);

-- 6. anon INSERT is blocked
SET LOCAL ROLE anon;

SELECT throws_ok(
  $tap$
  INSERT INTO storage.objects (id, bucket_id, name, owner, created_at, updated_at, last_accessed_at, metadata)
  VALUES (
    'f1145200-0000-0000-0000-000000000004'::uuid,
    'deal-documents',
    'b1145200-0000-0000-0000-000000000001/d1145200-0000-0000-0000-000000000001/documents/general/anon.pdf',
    null,
    now(), now(), now(), '{}'
  )
  $tap$,
  '42501',
  NULL,
  'anon INSERT is blocked'
);

-- 7. anon SELECT cannot see seeded deal-documents object
SELECT is(
  (
    SELECT COUNT(*)::int
    FROM storage.objects
    WHERE bucket_id = 'deal-documents'
      AND name = 'b1145200-0000-0000-0000-000000000001/d1145200-0000-0000-0000-000000000001/documents/general/test.pdf'
  ),
  0,
  'anon SELECT cannot see seeded deal-documents object'
);

-- 8. authenticated wrong tenant prefix INSERT is blocked
SELECT set_config('request.jwt.claims',
  '{"sub":"a1145200-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1145200-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

SELECT throws_ok(
  $tap$
  INSERT INTO storage.objects (id, bucket_id, name, owner, created_at, updated_at, last_accessed_at, metadata)
  VALUES (
    'f1145200-0000-0000-0000-000000000002'::uuid,
    'deal-documents',
    'b1145200-0000-0000-0000-000000000002/d1145200-0000-0000-0000-000000000001/documents/general/cross.pdf',
    'a1145200-0000-0000-0000-000000000001'::uuid,
    now(), now(), now(), '{}'
  )
  $tap$,
  '42501',
  NULL,
  'authenticated wrong tenant prefix INSERT is blocked'
);

-- 9. authenticated malformed path INSERT is blocked
SELECT throws_ok(
  $tap$
  INSERT INTO storage.objects (id, bucket_id, name, owner, created_at, updated_at, last_accessed_at, metadata)
  VALUES (
    'f1145200-0000-0000-0000-000000000003'::uuid,
    'deal-documents',
    'b1145200-0000-0000-0000-000000000001/random.pdf',
    'a1145200-0000-0000-0000-000000000001'::uuid,
    now(), now(), now(), '{}'
  )
  $tap$,
  '42501',
  NULL,
  'authenticated malformed path INSERT is blocked'
);

SELECT finish();
ROLLBACK;