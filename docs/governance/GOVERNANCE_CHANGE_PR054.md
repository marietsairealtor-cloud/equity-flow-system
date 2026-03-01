# Governance Change — PR054

## What changed
Prerequisite migration 20260219000017a_ensure_pgcrypto.sql inserted before 000018. Ensures pgcrypto extension exists in extensions schema before share_tokens table creation. Required because ship runs supabase db reset (fresh DB, all migrations sequential) and gen_random_bytes is not available without pgcrypto.

## Why safe
CREATE SCHEMA IF NOT EXISTS and CREATE EXTENSION IF NOT EXISTS are idempotent. No schema, privilege, or policy changes. No behavioral changes. Migration sorts before 000018 ensuring correct dependency order.

## Risk
None. Idempotent extension creation only.

## Also included
Modified scripts/ci_migration_schema_coupling.ps1 (merged in PR053) to handle schema-no-op migrations: when a migration changes but generated/schema.sql is byte-identical after regen, the gate now verifies schema is current and passes instead of failing. Required because corrective migration 000022 changed migration source without altering schema output.

## Rollback
Revert the PR. Remove migration 000017a. No data or schema impact.
