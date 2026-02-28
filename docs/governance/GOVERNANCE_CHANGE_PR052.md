# Governance Change — PR052

## Build Route Item
6.9 Foundation Surface Ready Trigger

## What changed
Added activity_log table with tenant_id FK, RLS enabled, two tenant-isolation policies (SELECT, INSERT) using current_tenant_id(). Added foundation_log_activity_v1 SECURITY DEFINER RPC with tenant context enforcement. REVOKE ALL on activity_log from anon and authenticated. GRANT EXECUTE on RPC to authenticated only. Updated execute_allowlist, definer_allowlist, and tenant_table_selector truth files.

## Why safe
Activity log is append-oriented with no UPDATE/DELETE policies — minimal attack surface. RPC follows identical SECURITY DEFINER pattern proven in create_deal_v1 and lookup_share_token_v1. Tenant isolation enforced both in RPC logic (current_tenant_id() match) and RLS. No existing tables, RPCs, or policies modified. No direct table grants to anon or authenticated.

## Risk
Low. New table and RPC only. No changes to existing surface. Activity log has no downstream consumers yet — purely foundational. Enum and role model from 6.8 untouched.

## Rollback
Drop RPC, drop RLS policies, drop activity_log table via reverse migration. Remove from allowlists and tenant_table_selector. Zero impact on existing surface.
