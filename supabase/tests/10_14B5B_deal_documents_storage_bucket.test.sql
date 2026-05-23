-- 10.14B5B: Deal Documents Storage Bucket + RLS Policies tests
BEGIN;

SELECT plan(10);

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

-- 6. INSERT policy exists for authenticated
SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deal_documents_insert_authenticated'
      AND roles @> ARRAY['authenticated']::name[]
      AND cmd = 'INSERT'
  ),
  'deal_documents_insert_authenticated policy exists for authenticated INSERT'
);

-- 7. SELECT policy exists for authenticated
SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deal_documents_select_authenticated'
      AND roles @> ARRAY['authenticated']::name[]
      AND cmd = 'SELECT'
  ),
  'deal_documents_select_authenticated policy exists for authenticated SELECT'
);

-- 8. no deal_documents storage policy grants anon access
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname LIKE 'deal_documents%'
      AND roles @> ARRAY['anon']::name[]
  ),
  'no deal_documents storage policy grants anon access'
);

-- 9. INSERT policy WITH CHECK enforces bucket + full tenant/path convention
SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deal_documents_insert_authenticated'
      AND with_check LIKE '%bucket_id%'
      AND with_check LIKE '%deal-documents%'
      AND with_check LIKE '%foldername%'
      AND with_check LIKE '%current_tenant_id%'
      AND with_check LIKE '%documents%'
      AND with_check LIKE '%signed_purchase_agreement%'
      AND with_check LIKE '%general%'
      AND with_check LIKE '%filename%'
  ),
  'INSERT policy WITH CHECK enforces bucket + tenant/path convention'
);

-- 10. SELECT policy USING enforces bucket + full tenant/path convention
SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deal_documents_select_authenticated'
      AND qual LIKE '%bucket_id%'
      AND qual LIKE '%deal-documents%'
      AND qual LIKE '%foldername%'
      AND qual LIKE '%current_tenant_id%'
      AND qual LIKE '%documents%'
      AND qual LIKE '%signed_purchase_agreement%'
      AND qual LIKE '%general%'
      AND qual LIKE '%filename%'
  ),
  'SELECT policy USING enforces bucket + tenant/path convention'
);

SELECT finish();
ROLLBACK;