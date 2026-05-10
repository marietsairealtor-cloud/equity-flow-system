-- 10.12D2 forward cleanup: remove abandoned Supabase Storage embed delivery path.
-- Canonical D2 delivery is GitHub Pages — apps/embed/*.html (see Build Route 10.12D2).
-- Does not modify prior applied migrations.
--
-- Storage schema blocks direct DELETE unless storage.allow_delete_query is set (platform guard).

SELECT set_config('storage.allow_delete_query', 'true', true);

DROP POLICY IF EXISTS "intake_forms_public_read_loader" ON storage.objects;

DELETE FROM storage.objects
WHERE bucket_id = 'intake-forms'
  AND name = 'loader.html';

DELETE FROM storage.buckets
WHERE id = 'intake-forms';
