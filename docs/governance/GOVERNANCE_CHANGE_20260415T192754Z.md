# GOVERNANCE CHANGE — 10.8.11P Expired / Archived Workspace UI Wiring
UTC: 20260415T192754Z

## What changed
- Post-auth routing updated: app_mode is now primary routing signal
  normal / read_only_expired → Today
  archived_unreachable → onboarding
- Expired banner updated:
  message: Subscription expired. This workspace is read-only. Renew within 60 days to avoid data loss.
  owner: Manage billing CTA visible
  admin/member: Contact your workspace owner to renew (no actionable CTA)
- Onboarding archived workspaces section added:
  data source: list_archived_workspaces_v1() only
  shows: workspace name, slug, subscription status, action button
  billing inactive: Subscribe to restore workspace → create-restore-checkout-session
  billing active: Restore workspace → restore_workspace_v1(p_restore_token)
  hidden when list is empty
- Hamburger menu: Archived workspaces item added
  visible when app_mode = normal AND archived workspaces list has items
  routes to onboarding archived workspaces section
- New Edge Function: create-restore-checkout-session deployed
  accepts restore_token from request body
  validates token against server-returned archived list for authenticated caller
  resolves tenant_id server-side for Stripe subscription metadata
  returns to /onboarding?restore_checkout=success (not /today)
  verify_jwt = false (handles own auth via bearer token + admin user lookup)
- supabase/config.toml: create-restore-checkout-session block added
- supabase/functions/create-checkout-session/index.ts: stray leading n removed
- WEWEB_ARCHITECTURE.md sections 13.1, 14, 14.1 updated
- CONTRACTS.md section 52 updated with 10.8.11P UI wiring notes
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
- No new RPCs
- No new migrations
- No schema changes
- UI derives all state from get_user_entitlements_v1() and list_archived_workspaces_v1() only
- No frontend date math or archive state invention
- Restore requires explicit owner action -- no auto-restore on billing sync
- create-restore-checkout-session validates ownership server-side via RPC
- tenant_id never returned to caller -- resolved server-side for Stripe only

## Risk
Low. UI-only changes plus one new Edge Function.
Edge Function is well-scoped: read archived list, validate token, create Stripe session.
No DB writes from Edge Function directly.

## Rollback
Revert this PR.
Remove create-restore-checkout-session from Supabase dashboard.
No DB migrations to rollback.