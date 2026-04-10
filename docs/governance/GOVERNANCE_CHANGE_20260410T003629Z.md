# GOVERNANCE CHANGE — 10.8.11I7 Re-Invite Email Delivery for Existing Users
UTC: 20260410T003629Z

## What changed
Added re-invite email delivery for existing users in 10.8.11I7:
- auth_user_exists_v1(p_email text) SECURITY DEFINER helper function created
  reads from auth.users, returns boolean only, service_role only
- send-invite-email Edge Function updated with two-path logic:
  new user: inviteUserByEmail (unchanged)
  existing user: signInWithOtp with shouldCreateUser: false
- Both paths redirect to APP_URL/auth
- APP_URL Edge Function secret added
- Supabase Magic Link email template updated for re-invite notification
- CONTRACTS.md section 48 added documenting helper and revised Edge Function
- definer_allowlist.json updated (auth_user_exists_v1, tenant context exempt)
- privilege_truth.json updated (service_role grant for auth_user_exists_v1)
- execute_allowlist.json: auth_user_exists_v1 NOT added (service_role only)
- rpc_contract_registry.json updated
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
auth_user_exists_v1 returns boolean only — no data leakage. service_role only.
shouldCreateUser: false prevents accidental user creation on OTP path.
Email failure remains non-blocking — invite row always created.
Magic Link template dependency documented at project level.
APP_URL guard prevents misconfigured redirect URLs.
No changes to existing invite acceptance flow or accept_pending_invites_v1.

## Risk
Low-medium. Magic Link email template is now shared between re-invite flow and
any future passwordless login. Documented in CONTRACTS.md section 48.
APP_URL must be configured in Edge Function secrets — if missing, function
returns 'misconfigured' and email is not sent but invite row is unaffected.

## Rollback
Revert this PR. Redeploy send-invite-email Edge Function to previous version.
Drop auth_user_exists_v1 function. Restore Magic Link email template.
No data migrations. No schema rollback required.