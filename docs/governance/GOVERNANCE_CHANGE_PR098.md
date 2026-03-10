# Governance Change PR098 — 8.8 Share Token Secure Generation Contract

## What changed
Added create_share_token_v1(uuid, timestamptz) RPC. Tokens are generated
using extensions.gen_random_bytes(32) — 256 bits entropy (>= 128 bit minimum).
Token format: shr_ prefix + 64 hex chars = 68 chars minimum. Full token
including prefix is hashed before storage. Raw token returned to caller only
at creation time — never persisted.

## Why safe
Additive — new RPC only. No changes to existing RPCs or schema. Token
generation uses approved secure source (gen_random_bytes). Hash-at-rest
maintained per 8.4 contract. Privilege firewall enforced: authenticated-only,
tenant-scoped via current_tenant_id().

## Risk
Low. New RPC with no side effects on existing token lookup or revocation paths.

## Rollback
Drop create_share_token_v1 via a single migration PR.
