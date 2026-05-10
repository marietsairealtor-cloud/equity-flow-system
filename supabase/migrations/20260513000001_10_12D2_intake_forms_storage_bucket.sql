-- 10.12D2: Public intake embed loader — Storage bucket
-- Hosts loader.html (uploaded separately). anon-readable single object path.
-- Edge Function intake-form remains source of truth for form HTML + config JSON.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'intake-forms',
  'intake-forms',
  true,
  1048576,
  ARRAY['text/html']
)
ON CONFLICT (id) DO UPDATE SET
  public             = true,
  file_size_limit    = 1048576,
  allowed_mime_types = ARRAY['text/html'];

-- Public read only for the loader object (defense in depth)
DROP POLICY IF EXISTS "intake_forms_public_read_loader" ON storage.objects;

CREATE POLICY "intake_forms_public_read_loader"
ON storage.objects
FOR SELECT
TO anon, authenticated
USING (
  bucket_id = 'intake-forms'
  AND name = 'loader.html'
);
