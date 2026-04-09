# GOVERNANCE CHANGE — 10.8.11I5 Seat Billing Sync on Invite Acceptance
UTC: 20260409T174927Z

## What changed
Added server-side seat billing sync for 10.8.11I5:
- trigger_seat_sync SECURITY DEFINER trigger function created on
  public.tenant_memberships AFTER INSERT and AFTER DELETE
- on_membership_insert_sync_seats trigger fires on member join
- on_membership_delete_sync_seats trigger fires on member removal
- sync-seat-count Edge Function deployed; counts active members and updates
  Stripe subscription quantity via STRIPE_PRICE_ID deterministic item lookup
- Seat count uses absolute recomputation — idempotent by design
- Sync failure is non-blocking; membership changes always succeed
- vault secret service_role_key used for Edge Function auth (same as 10.8.11I1)
- CONTRACTS.md section 47 added documenting trigger contract and dependencies
- definer_allowlist.json updated (trigger_seat_sync, tenant context exempt)
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 updated for 10.8.11I5

## Why safe
No changes to existing RPCs or membership logic. Triggers are additive only.
Sync failure path returns NEW/OLD — membership always created or deleted.
No secret embedded in migration SQL. Vault-backed auth only. Absolute seat
recomputation means duplicate trigger calls cannot overbill. No frontend role.
No direct Stripe calls from WeWeb.

## Risk
Medium. New infra dependency on vault secret, Edge Function, and Stripe API.
If any dependency is unavailable, seat sync silently fails but membership
changes are unaffected. Documented in CONTRACTS.md section 47.
STRIPE_PRICE_ID must match exact Stripe price ID including case — verified
during testing.

## Rollback
Revert this PR. Drop on_membership_insert_sync_seats and
on_membership_delete_sync_seats triggers. Drop trigger_seat_sync function.
Delete sync-seat-count Edge Function via Supabase dashboard.
No data migrations. No schema rollback required. Existing membership flow
unaffected.