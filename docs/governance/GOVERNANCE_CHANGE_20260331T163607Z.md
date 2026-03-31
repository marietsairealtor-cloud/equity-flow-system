## What changed
Added onboarding wizard page at /onboarding (Build Route 10.8.9). Implemented create-checkout-session Edge Function for Stripe Checkout redirect. Button workflow handles three cases: new slug (create workspace + checkout), slug taken by owner/admin (resume checkout), slug taken by other (show error). Added gs_slugCheckResult global variable to CONTRACTS §4. Registered 10.8.9 in qa_claim.json, qa_scope_map.json, ci_robot_owned_guard.ps1.

## Why safe
No direct table calls from WeWeb. All writes go through governed RPCs: create_tenant_v1, set_tenant_slug_v1, check_slug_access_v1. Stripe secret key never exposed to frontend. Checkout session created server-side via Edge Function. Webhook verified via Stripe signature before writing to DB. No invite token logic in onboarding. No non-invite join path.

## Risk
Low. Onboarding page is authenticated-only. All three case branches proven via manual testing. Edge Function deployed and verified. Stripe webhook proven working. No schema changes in this PR. No privilege changes beyond gs_slugCheckResult global variable addition to CONTRACTS.

## Rollback
Remove /onboarding page from WeWeb. Delete create-checkout-session Edge Function via Supabase dashboard. Revert CONTRACTS §4 gs_slugCheckResult addition. Revert qa_claim.json, qa_scope_map.json, ci_robot_owned_guard.ps1 entries. No data migration required.