# GOVERNANCE CHANGE -- 10.14B4B ACQ Backend Cleanup -- Remove Orphaned next_action Fields
UTC: 20260519T162254Z

## What changed
- Migration: 20260519000001_10_14B4B_next_action_cleanup.sql applied
- update_deal_property_v1: next_action and next_action_due removed from allowed keys
- update_deal_property_v1: envelope-safe require_min_role_v1('member') guard added
- get_acq_deal_v1: next_action and next_action_due removed from output
- list_acq_deals_v1: next_action and next_action_due removed from data.items output
- list_acq_deals_v1: envelope-safe require_min_role_v1('member') guard added
- All three RPCs: REVOKE from PUBLIC, anon; GRANT to authenticated
- next_action and next_action_due columns remain on public.deals (deprecated, not dropped)
- last_contacted_at retained in get_acq_deal_v1 -- cleanup deferred to 10.14B4C
- Reminder system (list_reminders_v1) remains authoritative follow-up path
- CONTRACTS.md updated
- WeWeb binding audit: no active UI binding reads next_action or next_action_due
- Tests: 10_14B4B_next_action_cleanup.test.sql (16 tests, all pass)
- 10_11A2_deal_edit_write_paths.test.sql updated to reflect new contract

## Why safe
No schema drop. Columns remain deprecated. No data loss.
All three RPC changes are internal logic only -- signatures unchanged.
WeWeb binding audit confirmed no active bindings before migration.

## Risk
Low. Additive guards + field removals from output. No schema change.
Existing data unaffected. Reminder system unchanged.

## Rollback
Revert PR. Re-run supabase db push to restore prior RPC bodies.