# GOVERNANCE CHANGE — 10.11A10 Acquisition Backend — Activity Log Expansion
UTC: 20260430T152847Z

## What changed
- Migration: 20260430000001_10_11A10_activity_log_expansion.sql applied
- advance_deal_stage_v1 updated:
    now requires both tenant + user context
    writes stage_change row to deal_activity_log on every valid transition
- handoff_to_dispo_v1 updated:
    now requires both tenant + user context
    writes handoff row to deal_activity_log on success
- complete_reminder_v1 updated:
    writes reminder_completed row to deal_activity_log on first completion only
    repeat calls return ok=true silent no-op -- no duplicate activity row
    cross-tenant completion returns ok=true silent no-op
- create_deal_note_v1 unchanged -- does not write to activity log
- deal_activity_log remains system-events only
- No schema changes. No new tables. No new columns.
- Tests: 10_11A10_activity_log_expansion.test.sql (17 tests, all pass)
- CONTRACTS.md section 62 added, sections 17, 55 updated
- rpc_contract_registry.json updated for 3 RPCs
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
All three RPCs use CREATE OR REPLACE -- no signature changes.
Activity log inserts are additive -- no existing data affected.
complete_reminder_v1 idempotency preserved -- existing callers unaffected.
No privilege changes.

## Risk
Low. Additive activity log writes only.
advance_deal_stage_v1 and handoff_to_dispo_v1 now require auth.uid() --
callers without user context will get NOT_AUTHORIZED instead of proceeding.
Mitigated: all WeWeb callers are authenticated users.

## Rollback
Revert PR. Re-run supabase db push.
Existing deal_activity_log rows unaffected.