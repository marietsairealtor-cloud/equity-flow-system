-- 10.8.7: TC Contract Storage Bucket
-- Creates tc-contracts bucket for executed contract PDFs.
-- One file per deal at exact path: {tenant_id}/{deal_id}/contract.pdf
-- PDF only, 10MB max, no anon access, tenant-member authenticated access only.
-- Tenancy resolved via current_tenant_id() per CONTRACTS s28 exception.
-- Full path contract enforced: 3 segments, segment[3] = contract.pdf.

-- Create bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'tc-contracts',
  'tc-contracts',
  false,
  10485760,
  ARRAY['application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
  public             = false,
  file_size_limit    = 10485760,
  allowed_mime_types = ARRAY['application/pdf'];

-- RLS: SELECT (download)
CREATE POLICY "tc_contracts_select_own"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'tc-contracts'
  AND array_length(string_to_array(name, '/'), 1) = 3
  AND (string_to_array(name, '/'))[1] = (public.current_tenant_id())::text
  AND (string_to_array(name, '/'))[3] = 'contract.pdf'
);

-- RLS: INSERT (upload)
CREATE POLICY "tc_contracts_insert_own"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'tc-contracts'
  AND array_length(string_to_array(name, '/'), 1) = 3
  AND (string_to_array(name, '/'))[1] = (public.current_tenant_id())::text
  AND (string_to_array(name, '/'))[3] = 'contract.pdf'
);

-- RLS: UPDATE (overwrite)
CREATE POLICY "tc_contracts_update_own"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'tc-contracts'
  AND array_length(string_to_array(name, '/'), 1) = 3
  AND (string_to_array(name, '/'))[1] = (public.current_tenant_id())::text
  AND (string_to_array(name, '/'))[3] = 'contract.pdf'
);

-- RLS: DELETE
CREATE POLICY "tc_contracts_delete_own"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'tc-contracts'
  AND array_length(string_to_array(name, '/'), 1) = 3
  AND (string_to_array(name, '/'))[1] = (public.current_tenant_id())::text
  AND (string_to_array(name, '/'))[3] = 'contract.pdf'
);