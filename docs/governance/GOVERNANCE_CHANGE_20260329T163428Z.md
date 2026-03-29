## What changed
Added Stripe billing foundation for onboarding Step 3 (Build Route 10.8.8C). Created Supabase Edge Function stripe-webhook that handles customer.subscription.created, customer.subscription.updated, and customer.subscription.deleted events. Writes and updates public.tenant_subscriptions on subscription lifecycle events. Stripe sandbox account created, test mode enabled, webhook endpoint configured and proven. Updated qa_claim.json, qa_scope_map.json, and ci_robot_owned_guard.ps1 to register 10.8.8C proof log path.

## Why safe
Edge Function uses SUPABASE_SERVICE_ROLE_KEY only for internal DB writes triggered by verified Stripe webhook signatures. Webhook signature verification enforced on every request via stripe.webhooks.constructEventAsync. No tenant_id accepted from caller -- tenant_id sourced exclusively from Stripe subscription metadata set server-side. No public RPC surface added. No schema changes. No privilege changes. tenant_subscriptions already governed and RLS-protected. get_user_entitlements_v1 already reads tenant_subscriptions -- no changes required.

## Risk
Low. Edge Function is additive only. No existing RPCs modified. No schema changes. Webhook signature verification prevents unauthorized writes. Only risk is Stripe API version compatibility -- mitigated by pinning stripe SDK to v13.11.0 with apiVersion 2023-10-16. Test mode only -- no live charges possible.

## Rollback
Delete stripe-webhook Edge Function via Supabase dashboard or CLI. Remove STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET from Supabase secrets. Disable webhook endpoint in Stripe dashboard. Revert qa_claim.json, qa_scope_map.json, ci_robot_owned_guard.ps1 entries. No data migration required. tenant_subscriptions data can remain or be cleared manually.