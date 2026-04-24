# GOVERNANCE CHANGE — 10.11A4 Acquisition Backend — KPI Date Range Filter
UTC: 20260424T003808Z

## What changed
- Migration: 20260423000002_10_11A4_acq_kpi_date_range.sql applied
- Dropped old zero-arg surface: get_acq_kpis_v1()
- New signature: get_acq_kpis_v1(p_date_from timestamptz DEFAULT NULL, p_date_to timestamptz DEFAULT NULL)
- Filter behavior:
  - both null -> all time (existing behavior preserved)
  - p_date_from only -> created_at >= p_date_from
  - p_date_to only -> created_at <= p_date_to
  - both provided -> filter within range
  - p_date_to < p_date_from -> VALIDATION_ERROR
- avg_assignment_fee now uses latest deal_inputs row per deal (ORDER BY created_at DESC, id DESC)
- No schema changes. No new tables. No new columns.
- Tests: 10_11A4_acq_kpi_date_range.test.sql (12 tests, all pass)
- CONTRACTS.md updated -- get_acq_kpis_v1 signature and behavior documented
- rpc_contract_registry.json updated
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
Old zero-arg surface explicitly dropped before new surface created -- no overload conflict.
New params have DEFAULT NULL -- callers passing no args get all-time behavior unchanged.
avg_assignment_fee fix is correctness improvement only -- one deterministic row per deal.
No privilege changes. No new RPCs. No schema changes.

## Risk
Low-medium. DROP FUNCTION on old surface -- any caller that hardcodes zero-arg call will break.
Mitigated: WeWeb wiring uses DEFAULT NULL params -- passing no args still works.
All existing tests pass.

## Rollback
Revert PR. Re-run supabase db push.
Note: rollback requires re-creating the old zero-arg surface manually if needed.