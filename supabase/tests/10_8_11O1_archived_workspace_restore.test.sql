-- 10.8.11O1: Corrective compatibility test
-- Asserts zero-parameter restore_workspace_v1() was dropped in 10.8.11O3.
-- Asserts token-based restore_workspace_v1(uuid) now exists.
BEGIN;

SELECT plan(2);

-- 1. Old zero-parameter signature no longer exists
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'restore_workspace_v1'
      AND p.pronargs = 0
  ),
  'O1 corrective: zero-parameter restore_workspace_v1() no longer exists'
);

-- 2. New token-based signature exists
SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'restore_workspace_v1'
      AND p.pronargs = 1
  ),
  'O3 corrective: restore_workspace_v1(uuid) exists'
);

SELECT finish();
ROLLBACK;