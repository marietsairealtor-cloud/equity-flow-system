# GOVERNANCE CHANGE — 10.8.11N Expired Subscription Server-Side Write Lock
UTC: 20260413T011045Z

## What changed
Added server-side write lock to all workspace-write RPCs via internal helper:
- check_workspace_write_allowed_v1() added: SECURITY DEFINER, internal only,
  REVOKE ALL FROM PUBLIC, membership enforced internally, returns false for
  no tenant, not a member, no subscription, canceled, expired
- Retrofitted write RPCs: create_deal_v1, update_deal_v1, create_farm_area_v1,
  delete_farm_area_v1, create_reminder_v1, complete_reminder_v1,
  create_share_token_v1, update_workspace_settings_v1, update_member_role_v1,
  remove_member_v1, invite_workspace_member_v1
- submit_form_v1: inline subscription check, blocked when workspace expired
- lookup_share_token_v1: inline subscription check, blocked when workspace expired
- Approved exceptions: update_display_name_v1 (profile settings), billing path
- Universal error message: This workspace is read-only. Renew your subscription to continue.
- create_active_workspace_seed_v1() added: test-only seed helper, SECURITY DEFINER,
  REVOKE ALL FROM PUBLIC, seeds tenant + auth user + membership + subscription + profile
- Existing pgTAP test files retrofitted with active subscription seeds
- CONTRACTS.md sections 17 and 17A updated
- definer_allowlist.json updated for check_workspace_write_allowed_v1
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
Write lock is additive enforcement. No schema changes. No new public RPCs.
helper is internal only -- not granted to authenticated or anon.
Approved exceptions remain unblocked. Renewal unlock is automatic via
Stripe webhook -> DB status update -> entitlement RPC reflects new state.
Lane-only gate.

## Risk
Medium. Retrofits existing write RPCs. All existing tests updated and passing
(548 tests, 0 failures). Universal error message used consistently.
Future write RPCs protected by 10.8.11N1 merge-blocking gate.

## Rollback
Revert this PR. Re-run supabase db push to restore previous function definitions.
No data migrations. No schema rollback required.