# Governance Change — PR054

## What changed
Prerequisite migration 20260218000001_ensure_pgcrypto.sql added before all existing migrations. Ensures pgcrypto extension exists in extensions schema before share_tokens table creation (migration 000018). Required because ship runs supabase db reset (fresh DB, all migrations sequential) and gen_random_bytes is not available without pgcrypto. Deleted invalid migration file 20260219000017a_ensure_pgcrypto.sql (suffix filenames not permitted, duplicate version key).

Also included: scripts/ci_migration_schema_coupling.ps1 modified in PR053 to handle schema-no-op migrations.

## Why safe
CREATE EXTENSION IF NOT EXISTS is idempotent. No schema, privilege, or policy changes. No behavioral changes. Migration sorts before all existing migrations ensuring correct dependency order.

## Risk
None. Idempotent extension creation only.

## Rollback
Revert the PR. Remove migration 20260218000001. No data or schema impact.
