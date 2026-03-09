# Governance Change PR096 — 8.6 Share Token Revocation

## What changed
Added revoked_at column to share_tokens table. Updated lookup_share_token_v1
to enforce revocation (revoked tokens return NOT_FOUND — no existence leak).
Added revoke_share_token_v1 RPC (idempotent). Revocation overrides expiration.

## Why safe
Additive schema change (new nullable column, default NULL). Existing tokens
unaffected. lookup_share_token_v1 behavior unchanged for non-revoked tokens.
New RPC is authenticated-only, tenant-scoped via current_tenant_id().

## Risk
Low. revoked_at IS NULL check added to lookup path — existing valid tokens
pass this check. No migration of existing data required.

## Rollback
Revert migration 20260309000000 to drop revoked_at column and restore
previous lookup_share_token_v1 body. Drop revoke_share_token_v1.
