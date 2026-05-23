-- 10.14B5B: Deal Documents Storage Bucket + RLS Policies
-- Creates deal-documents Supabase Storage bucket with tenant-scoped RLS policies.
-- Authenticated users may upload/read only within their own tenant path prefix
-- and only under the governed path convention:
--   {tenant_id}/{deal_id}/documents/{document_type}/{filename}
-- No public access. No anon access. 10 MB file size limit.
-- Storage file deletion remains out of scope.
-- attach_deal_document_v1 remains the governed metadata record path.
-- list_deal_documents_v1 remains the governed metadata list path.

-- Create bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'deal-documents',
  'deal-documents',
  false,
  10485760,
  ARRAY[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp'
  ]
);

-- Authenticated upload policy: full path convention enforced
-- Path convention: {tenant_id}/{deal_id}/documents/{document_type}/{filename}
CREATE POLICY "deal_documents_insert_authenticated"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'deal-documents'
  AND (storage.foldername(name))[1] = (public.current_tenant_id())::text
  AND (storage.foldername(name))[2] IS NOT NULL
  AND (storage.foldername(name))[2] <> ''
  AND (storage.foldername(name))[3] = 'documents'
  AND (storage.foldername(name))[4] IN ('general', 'signed_purchase_agreement')
  AND storage.filename(name) IS NOT NULL
  AND storage.filename(name) <> ''
);

-- Authenticated read policy: full path convention enforced
CREATE POLICY "deal_documents_select_authenticated"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'deal-documents'
  AND (storage.foldername(name))[1] = (public.current_tenant_id())::text
  AND (storage.foldername(name))[2] IS NOT NULL
  AND (storage.foldername(name))[2] <> ''
  AND (storage.foldername(name))[3] = 'documents'
  AND (storage.foldername(name))[4] IN ('general', 'signed_purchase_agreement')
  AND storage.filename(name) IS NOT NULL
  AND storage.filename(name) <> ''
);