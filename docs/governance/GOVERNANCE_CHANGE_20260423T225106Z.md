# GOVERNANCE CHANGE — 10.11A3 Acquisition Backend — Deal Detail Read Path Corrections
UTC: 20260423T225106Z

## What changed
- Migration: 20260423000001_10_11A3_acq_deal_detail_read_corrections.sql applied
- get_acq_deal_v1 extended with:
  - mao: sourced from deal_inputs.assumptions->>'mao'
  - multiplier: sourced from deal_inputs.assumptions->>'multiplier'
  - last_contacted_at: derived from most recent deal_notes.created_at where note_type = 'call_log'
  - last_contacted_at returns null when no call_log exists
  - p_deal_id IS NULL guard added returning VALIDATION_ERROR
- No new RPC. No schema changes. No new tables. No new columns.
- All existing get_acq_deal_v1 fields preserved -- no regression.
- Tests: 10_11A3_acq_deal_detail_read_corrections.test.sql (10 tests, all pass)
- CONTRACTS.md updated -- get_acq_deal_v1 pricing and last_contacted_at documented
- rpc_contract_registry.json updated
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
Additive return fields only. No signature change. No new RPCs.
CREATE OR REPLACE acceptable -- all existing callers unaffected.
last_contacted_at derived server-side only -- no frontend date math.
No write path changes. No privilege changes.

## Risk
Low. Read-only extension. New fields ignored by existing callers.

## Rollback
Revert PR. Re-run supabase db push to restore prior function definition.
No data migrations. No schema rollback required.