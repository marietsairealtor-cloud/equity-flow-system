# GOVERNANCE CHANGE — 10.8.11O Expired Workspace Retention + Archive Lifecycle Automation
UTC: 20260413T171511Z

## What changed
- Added public.tenants.subscription_lapsed_at timestamptz DEFAULT NULL
- Added public.tenants.archived_at timestamptz DEFAULT NULL
- Added internal RPC public.process_workspace_retention_v1() -- service_role only
- Added Supabase Edge Function supabase/functions/retention-lifecycle/index.ts
- CONTRACTS.md section 50 added
- definer_allowlist.json, privilege_truth.json, rpc_contract_registry.json updated
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Lifecycle enforced
1. Recovery: clears subscription_lapsed_at when active subscription returns before archive
2. Lapse detection: sets subscription_lapsed_at on first run for membership + no subscription
3. Archive: workspaces expired beyond 60-day anchor are transitioned to archived_at
4. Hard delete: workspaces archived beyond 6 months are deleted in explicit order

## Explicit delete order
1. DELETE FROM public.activity_log
2. DELETE FROM public.tenant_memberships
3. DELETE FROM public.tenants (CASCADE handles remaining FK children)

## Renewal behavior
- Renew within 60-day window: subscription_lapsed_at cleared, archive does not occur
- Renew after archive: explicit restore required (10.8.11O1), not automatic
- Renew after hard delete: no recovery

## Why safe
- No public-facing RPC added
- No authenticated or anon grants
- Schema changes are additive only (DEFAULT NULL columns)
- Hard delete uses explicit order, not blind FK cascade reliance
- Edge Function uses service_role client only
- No WeWeb access path

## Risk
Medium. Hard delete is irreversible. Mitigated by:
- 60-day read-only window before archive
- 6-month archive window before hard delete
- Explicit delete order documented and tested
- Recovery path clears lapsed state on renewal

## Rollback
Revert this PR. Run supabase db push to restore previous schema.
Drop archived_at and subscription_lapsed_at columns from tenants.
Remove retention-lifecycle Edge Function from dashboard.
No data recovery possible for already hard-deleted workspaces.