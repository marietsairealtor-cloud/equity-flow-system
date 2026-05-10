-- 10.12D2 cleanup: abandoned Storage embed path removed (GitHub Pages apps/embed is canonical).
--
-- Asserts migration `20260513000002_10_12D2_cleanup_intake_forms_storage.sql` effects,
-- after `20260513000001_10_12D2_intake_forms_storage_bucket.sql` has applied historically.
-- Fresh DB: `supabase db reset` (or equivalent) so both migrations apply in order.
BEGIN;

SELECT plan(4);

SELECT has_table('storage', 'buckets', '10.12D2 cleanup: storage.buckets exists');

SELECT ok(
  NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'intake-forms'),
  '10.12D2 cleanup: intake-forms bucket removed'
);

SELECT ok(
  NOT EXISTS (SELECT 1 FROM storage.objects WHERE bucket_id = 'intake-forms'),
  '10.12D2 cleanup: no storage.objects rows for intake-forms'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'intake_forms_public_read_loader'
  ),
  '10.12D2 cleanup: intake_forms_public_read_loader policy removed'
);

SELECT finish();
ROLLBACK;
