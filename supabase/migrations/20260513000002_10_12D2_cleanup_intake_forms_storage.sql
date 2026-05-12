-- 10.12D2 forward cleanup: remove abandoned Supabase Storage embed delivery path.
-- Canonical D2 delivery is GitHub Pages — apps/embed/*.html (see Build Route 10.12D2).
-- Does not modify prior applied migrations.
--
-- Storage schema blocks direct DELETE unless storage.allow_delete_query is set (platform guard).
-- Run set_config + deletes inside a single DO block so one migration *statement* keeps the GUC
-- visible to storage.protect_delete() even when the CLI runs multi-statement files oddly.

DROP POLICY IF EXISTS "intake_forms_public_read_loader" ON storage.objects;

DO $cleanup$
BEGIN
  PERFORM set_config('storage.allow_delete_query', 'true', true);

  DELETE FROM storage.objects
  WHERE bucket_id = 'intake-forms';

  DELETE FROM storage.buckets
  WHERE id = 'intake-forms';
END;
$cleanup$;
