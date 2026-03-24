# GOVERNANCE_CHANGE — Build Route 10.8.7C

Item: 10.8.7C — Tenant Context Parity Fixes (user_profiles + current_tenant_id)
Date: 2026-03-23

---

## What changed

Forward migration adds `public.user_profiles.current_tenant_id UUID NULL` with FK to `public.tenants(id) ON DELETE SET NULL`. Corrects `public.current_tenant_id()` to resolve tenant context in CONTRACTS §3 order: (1) user_profiles.current_tenant_id, (2) app.tenant_id, (3) JWT tenant claim, (4) NULL. Adds minimum RLS policy on user_profiles so authenticated users can read their own row. No invite flow, routing, auth.users, or unrelated profile field changes.

---

## Why safe

Parity fix only. Column is nullable — no existing rows affected. FK uses ON DELETE SET NULL. current_tenant_id() preserves JWT as fallback. RLS policy is own-row-only via auth.uid() = id. Does not widen access beyond the controlled exception in CONTRACTS §12. get_user_entitlements_v1 signature unchanged.

---

## Risk

Low. Nullable column addition is non-breaking. FK ON DELETE SET NULL prevents hard failures. RLS policy is additive and scoped to self-read only. Gate is lane-only.

---

## Rollback

Revert the forward migration(s) in this PR. Drop user_profiles.current_tenant_id, drop FK, restore current_tenant_id() prior body, drop added RLS policy. No data migration required. Re-run npm run handoff on main after revert.
