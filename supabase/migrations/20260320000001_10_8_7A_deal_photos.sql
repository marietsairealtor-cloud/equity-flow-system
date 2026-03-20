-- 10.8.7A: Deal Photos Storage Bucket
-- Creates deal-photos bucket for deal photos used by Acquisition and Deal Viewer.
-- Path: {tenant_id}/{deal_id}/{photo_id}.jpg|.png
-- JPEG and PNG only, 10MB per file, no anon access.
-- Multiple photos per deal supported. No transformations (V1 boundary).
-- Tenancy resolved via current_tenant_id() per CONTRACTS s28 exception.
-- Path contract enforced: 3 segments, segment[1]=tenant_id,
-- segment[3] ends in .jpg or .png.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'deal-photos',
  'deal-photos',
  false,
  10485760,
  ARRAY['image/jpeg', 'image/png']
)
ON CONFLICT (id) DO UPDATE SET
  public             = false,
  file_size_limit    = 10485760,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png'];

-- RLS: SELECT (read)
CREATE POLICY "deal_photos_select_own"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'deal-photos'
  AND array_length(string_to_array(name, '/'), 1) = 3
  AND (string_to_array(name, '/'))[1] = (public.current_tenant_id())::text
  AND (
    (string_to_array(name, '/'))[3] ILIKE '%.jpg'
    OR (string_to_array(name, '/'))[3] ILIKE '%.png'
  )
);

-- RLS: INSERT (upload)
CREATE POLICY "deal_photos_insert_own"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'deal-photos'
  AND array_length(string_to_array(name, '/'), 1) = 3
  AND (string_to_array(name, '/'))[1] = (public.current_tenant_id())::text
  AND (
    (string_to_array(name, '/'))[3] ILIKE '%.jpg'
    OR (string_to_array(name, '/'))[3] ILIKE '%.png'
  )
);

-- RLS: UPDATE
CREATE POLICY "deal_photos_update_own"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'deal-photos'
  AND array_length(string_to_array(name, '/'), 1) = 3
  AND (string_to_array(name, '/'))[1] = (public.current_tenant_id())::text
  AND (
    (string_to_array(name, '/'))[3] ILIKE '%.jpg'
    OR (string_to_array(name, '/'))[3] ILIKE '%.png'
  )
);

-- RLS: DELETE
CREATE POLICY "deal_photos_delete_own"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'deal-photos'
  AND array_length(string_to_array(name, '/'), 1) = 3
  AND (string_to_array(name, '/'))[1] = (public.current_tenant_id())::text
  AND (
    (string_to_array(name, '/'))[3] ILIKE '%.jpg'
    OR (string_to_array(name, '/'))[3] ILIKE '%.png'
  )
);