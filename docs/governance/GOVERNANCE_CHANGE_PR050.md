# Governance Change — PR050

## What changed
Build Route 6.7 Share-Link Surface. Added share_tokens table with tenant-scoped unique constraint (tenant_id, token). Added share_token_packet view (allowlist-only field exposure). Added lookup_share_token_v1 SECURITY DEFINER RPC with two-predicate WHERE (token AND tenant_id as parameters). Added TOKEN_EXPIRED to CONTRACTS.md S1 envelope code enum (additive-only). Updated definer_allowlist, execute_allowlist, tenant_table_selector. 6 pgTAP tests including cross-tenant negative test and expiry semantics. EXPLAIN proof in proof log confirms planner uses tenant_id predicate via composite index.

## Why safe
New table with RLS enabled, default deny, REVOKE ALL. No direct grants. Access via SD RPC only. Tenant isolation enforced by two-predicate WHERE + composite unique index. TOKEN_EXPIRED is additive to envelope enum (no breaking change). Packet view exposes only allowlisted fields.

## Risk
Low-medium. New table + RPC + contract addendum. Mitigated by pgTAP cross-tenant negative test, EXPLAIN planner evidence, definer safety audit, anon privilege audit.

## Rollback
Revert PR. Drop migrations 000018-000019. Remove TOKEN_EXPIRED from CONTRACTS.md S1. Restore truth files. No data impact.
