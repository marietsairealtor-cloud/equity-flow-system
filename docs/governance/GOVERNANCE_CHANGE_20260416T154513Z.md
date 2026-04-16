# GOVERNANCE CHANGE — 10.8.12 1-Month Free Trial (One-Time, User-Scoped)
UTC: 20260416T154513Z

## What changed
- Migration 20260415000001_10_8_12_free_trial.sql applied
- user_profiles.has_used_trial boolean NOT NULL DEFAULT false added
- user_profiles.trial_claimed_at timestamptz DEFAULT NULL added
- user_profiles.trial_started_at timestamptz DEFAULT NULL added
- claim_trial_v1() added: SECURITY DEFINER, authenticated only, tenant context exempt
  Atomic reservation via UPDATE ... RETURNING
  Eligible when has_used_trial = false AND (trial_claimed_at IS NULL OR expired > 2 hours)
  Returns trial_eligible: true/false, trial_period_days: 30/null
  No DB write on ineligible path
- confirm_trial_v1(p_user_id uuid, p_tenant_id uuid) added: SECURITY DEFINER, service_role only
  Called by stripe-webhook after customer.subscription.created with trialing status
  Validates: profile exists, owner of tenant, valid non-expired reservation
  Sets has_used_trial = true, trial_started_at = now()
  Idempotent: already confirmed returns OK
- tenant_subscriptions_status_check constraint updated to allow trialing
- upsert_subscription_v1() updated: trialing added to allowed statuses
- get_user_entitlements_v1() updated: trialing returned and treated as active for routing/access
- create-checkout-session Edge Function updated:
  calls claim_trial_v1() atomically before Stripe session creation
  applies trial_period_days = 30 when eligible
  passes user_id in subscription_data.metadata for webhook confirm path
  trial claim failure is fatal -- no silent fallback
- stripe-webhook Edge Function updated:
  resolveStatus() now persists raw Stripe status only -- no expiring derivation
  calls confirm_trial_v1() on customer.subscription.created + trialing + user_id present
  confirm_trial_v1() failure is fatal -- Stripe will retry
  all RPC calls now validate both transport error and envelope ok
- CONTRACTS.md section 53 added, section 17 updated, billing/entitlement sections updated
- definer_allowlist.json, execute_allowlist.json, privilege_truth.json updated
- rpc_contract_registry.json updated
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
- Trial is user-scoped not tenant-scoped -- no cross-tenant risk
- Atomic reservation prevents double-claim race condition
- Trial not burned until Stripe confirms subscription (two-phase design)
- Stale reservation expires after 2 hours -- abandoned checkout recoverable
- No frontend trial logic -- all enforcement is backend
- No coupons or promo codes -- Stripe native trial only
- upsert_subscription_v1 and check constraint updated consistently

## Risk
Low-medium. New trial feature touches billing path.
Mitigated by:
- Two-phase atomic design
- Fatal failure on confirm_trial_v1 error (Stripe retries)
- Stale reservation recovery window
- All RPC envelope failures checked in webhook

## Rollback
Revert this PR. Run supabase db push to restore previous functions and constraint.
ALTER TABLE user_profiles DROP COLUMN has_used_trial, trial_claimed_at, trial_started_at.
Redeploy previous Edge Function versions.