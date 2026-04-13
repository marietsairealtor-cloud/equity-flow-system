# GOVERNANCE CHANGE — 10.8.11O1 Archived Workspace Restore Implementation
UTC: 20260413T235632Z

## What changed
- Migration 20260413000002_10_8_11O1_archived_workspace_restore.sql applied
- Added public.restore_workspace_v1() -- owner-only, authenticated only
  Clears tenants.archived_at and tenants.subscription_lapsed_at on success
  Requires: workspace archived, tenant row exists, owner role, active subscription
  Returns NOT_AUTHORIZED for non-owner
  Returns CONFLICT for not-archived, no active subscription, hard-deleted workspace
- CONTRACTS.md section 51 added
- CONTRACTS.md section 17 mapping table updated
- definer_allowlist.json, execute_allowlist.json, privilege_truth.json updated
- rpc_contract_registry.json updated
- ci_write_lock_coverage.ps1: restore_workspace_v1 added to approved full exemptions
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
- No schema changes
- No new columns
- Additive RPC only
- Owner-only enforcement
- No caller-supplied tenant_id or user_id
- Approved write-lock exemption: restore is the mechanism that re-enables access,
  not a normal workspace write action
- Renewal alone does not trigger restore -- explicit call required

## Risk
Low. Single owner-only RPC. No schema changes. No cascade effects.
Restore only clears two nullable columns on the tenant row.

## Rollback
Revert this PR. Run supabase db push to drop restore_workspace_v1().
No data migrations. No schema rollback required.