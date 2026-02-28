# Governance Change — PR053

## What changed
Schema-qualified gen_random_bytes call in migration 20260219000018_share_tokens.sql from gen_random_bytes(32) to extensions.gen_random_bytes(32). CI clean-room DB does not have pgcrypto in public schema — function lives in extensions schema per Supabase default.

## Why safe
Single token default expression change. No schema, privilege, or policy changes. All 53 tests pass. Migration applies cleanly in both local and CI environments.

## Risk
None. Cosmetic fix to existing migration. No behavioral change.

## Rollback
Revert the PR. No data or schema impact.
