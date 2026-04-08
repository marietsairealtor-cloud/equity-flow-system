# GOVERNANCE CHANGE — 10.8.11I1 Invite Email Delivery
UTC: 20260408T010609Z

## What changed
Added server-side invite email delivery for 10.8.11I1:
- pg_net extension enabled in extensions schema
- trigger_invite_email SECURITY DEFINER trigger function created on
  public.tenant_invites AFTER INSERT to call send-invite-email Edge Function
- send-invite-email Edge Function deployed; calls supabase.auth.admin.inviteUserByEmail
- Vault secret service_role_key added for trigger auth header injection
- Email failure is non-blocking; invite creation always succeeds
- CONTRACTS.md section 45 added documenting trigger contract and dependencies
- definer_allowlist.json updated with trigger_invite_email (tenant context exempt)
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 updated for 10.8.11I1

## Why safe
No changes to existing RPCs or invite acceptance flow. Trigger is additive only.
Email failure path returns NEW — invite row always created. No frontend email logic.
No secret embedded in migration SQL. Vault-backed auth only. Edge Function uses
built-in Supabase service role env var. pg_net is an approved Supabase extension.

## Risk
Low-medium. New infra dependency on vault secret and Edge Function availability.
If vault secret is missing or Edge Function is undeployed, email silently fails
but invite creation is unaffected. Documented in CONTRACTS.md section 45.

## Rollback
Revert this PR. Drop trigger on public.tenant_invites. Drop trigger_invite_email
function. Remove pg_net extension if no other consumers. Delete send-invite-email
Edge Function via Supabase dashboard. Remove vault secret service_role_key.