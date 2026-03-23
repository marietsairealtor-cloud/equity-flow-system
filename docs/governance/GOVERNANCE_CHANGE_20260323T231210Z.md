# GOVERNANCE_CHANGE — Build Route 10.8.7C

Item: 10.8.7C — Tenant Context Parity Fixes (user_profiles + current_tenant_id)
Date: 2026-03-23

---

## What changed

Forward migration adds `public.user_profiles.current_tenant_id UUID NULL` with FK to `public.tenants(id) ON DELETE SET NULL`. Corrects `public.current_tenant_id()` via DROP + CREATE to resolve tenant context in CONTRACTS §3 order: (1) user_profiles.current_tenant_id, (2) app.tenant_id, (3) JWT tenant claim, (4) NULL. Adds minimum RLS policy `user_profiles_select_self` on `public.user_profiles` so authenticated users can read their own row, unblocking tenant resolution under RLS. No invite flow, routing, auth.users, or unrelated profile field changes.

---

## Why safe

Parity fix only — closes gap between CONTRACTS §3 tenancy resolution order and actual cloud database state. Column is nullable, no existing rows affected. FK uses ON DELETE SET NULL, preventing hard failures on tenant deletion. current_tenant_id() correction preserves JWT as fallback (step 3). RLS policy is own-row-only via auth.uid() = id — does not widen access beyond the documented controlled exception in CONTRACTS §12. get_user_entitlements_v1 signature is unchanged. current_tenant_id() was already SECURITY DEFINER and already in definer_allowlist.json — DROP + CREATE does not change its privilege classification.

---

## Risk

Low. Nullable column addition is non-breaking. FK ON DELETE SET NULL prevents hard failures. current_tenant_id() correction is additive — JWT path preserved as fallback. RLS policy is additive and scoped to self-read only. Gate is lane-only.

---

## Rollback

Revert the forward migration in this PR. Drop user_profiles.current_tenant_id column, drop FK constraint, restore current_tenant_id() prior body via DROP + CREATE, drop user_profiles_select_self RLS policy. No data migration required on rollback — column is nullable and new. Re-run npm run handoff on main after revert to regenerate schema artifacts.
