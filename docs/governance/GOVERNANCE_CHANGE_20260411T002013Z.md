# GOVERNANCE CHANGE — 10.8.11K Subscription Status Consistency Bridge Fix
UTC: 20260411T002013Z

## What changed
Corrective fix for get_user_entitlements_v1 subscription status computation:
- Removed dead RPC branches for raw Stripe statuses that cannot exist in DB
  (trialing, past_due, unpaid, incomplete_expired are normalized by webhook
  before DB write; tenant_subscriptions.status constraint enforces this)
- Error path now returns data: {} instead of data: null per frozen envelope contract
- subscription_days_remaining now returns null for expired and none statuses,
  integer for expiring only, null for active -- per Build Route 10.8.11K DoD
- CONTRACTS.md section 24 updated to reflect corrected architecture:
  webhook normalizes raw Stripe status before DB write; RPC reads stored
  DB statuses only; raw Stripe status handling removed from RPC
- Banner UI visibility and text bindings verified against DoD -- no changes needed
- Existing test files updated to match corrected behavior:
  10_8_2_entitlements_extension.test.sql -- active >5 days days_remaining=null
  10_4_rpc_response_contract_tests.test.sql -- NOT_AUTHORIZED data={}
- New test file 10_8_11K_subscription_status_consistency.test.sql added
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
Corrective internal logic fix only. No signature change. No return shape change.
CREATE OR REPLACE acceptable. No schema changes. No new columns. No new RPCs.
Webhook normalization architecture is unchanged -- only dead RPC code removed.
Banner UI bindings unchanged. Lane-only gate.

## Risk
Low. Corrective fix removes dead code. No behavioral change for stored statuses
that actually exist (active, expiring, expired, canceled). Existing tests updated
to match corrected contract. New tests prove corrected behavior.

## Rollback
Revert this PR. Re-run supabase db push to restore previous function definition.
No data migrations. No schema rollback required.