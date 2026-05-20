# GOVERNANCE CHANGE -- 10.14B4C ACQ Backend Cleanup -- Remove Unused Call Log Surface
UTC: 20260520T144259Z

## What changed
- Migration: 20260520000001_10_14B4C_call_log_cleanup.sql applied
- create_deal_note_v1: rejects note_type = 'call_log' with VALIDATION_ERROR
- create_deal_note_v1: envelope-safe require_min_role_v1('member') guard added
- create_deal_note_v1: guard order corrected (tenant -> member -> write-lock -> validation)
- get_acq_deal_v1: last_contacted_at removed from output
- get_acq_deal_v1: v_last_contacted DECLARE and call_log query removed
- Existing historical call_log rows in deal_notes NOT deleted
- list_deal_notes_v1 unchanged -- historical call_log notes remain readable
- No schema changes. No new tables. No new RPCs. No signature changes.
- CONTRACTS.md updated
- WeWeb binding audit: no active UI binding reads last_contacted_at (changed to updated_at in 10.14B4)
- Tests: 10_14B4C_call_log_cleanup.test.sql (13 tests, all pass)
- 10_11A1_deal_notes_activity_log.test.sql updated to reflect new contract
- 10_11A3_acq_deal_detail_read_corrections.test.sql updated to reflect new contract

## Why safe
No schema drop. No data deletion. Historical call_log rows remain readable.
create_deal_note_v1 signature unchanged -- only validation tightened.
get_acq_deal_v1 signature unchanged -- only output field removed.
No active WeWeb binding reads last_contacted_at.

## Risk
Low. Additive validation + output field removal. No schema change. No data loss.

## Rollback
Revert PR. Re-run supabase db push to restore prior RPC bodies.