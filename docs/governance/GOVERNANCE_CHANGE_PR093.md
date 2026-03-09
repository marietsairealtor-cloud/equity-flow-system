# Governance Change — PR093

## What changed
Added two migrations for share token hash-at-rest (8.4). Migration 20260308000000 converts share_tokens table from raw token to token_hash (SHA-256 via pgcrypto). Migration 20260308000001 updates lookup_share_token_v1 RPC to hash input before comparison and updates share_token_packet view. Added pgTAP test proving hash-at-rest properties. Updated CONTRACTS.md with §18 documenting the behavioral change. Bumped calc_version_registry.json (calc-adjacent token in migration, no logic change).

## Why safe
Share tokens are now stored as irreversible SHA-256 hashes. Raw tokens never persisted. Lookup RPC signature unchanged. No new security surface — this strengthens existing surface by removing plaintext storage. pgTAP tests prove: no raw token column, lookup succeeds with correct hash, lookup fails with altered hash.

## Risk
Low. Existing share tokens are migrated via hash of current value. Any client holding a raw token can still look it up (RPC hashes input). If pgcrypto extension is unavailable, digest() calls fail — but pgcrypto is already a dependency (ensured by 20260218000001_ensure_pgcrypto.sql).

## Rollback
Reverse migration: add token column back, populate from backup (not possible from hash — requires token re-issuance). Revert RPC and view. This is a one-way migration by design.