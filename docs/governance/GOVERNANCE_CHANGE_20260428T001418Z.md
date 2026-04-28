# GOVERNANCE CHANGE — 10.11A7 Acquisition Backend — Deal Pricing Write Path
UTC: 20260428T001418Z

## What changed
- Migration: 20260427000001_10_11A7_deal_pricing_write_path.sql applied
- New RPC: update_deal_pricing_v1(p_deal_id uuid, p_fields jsonb)
    SECURITY DEFINER, authenticated only, write lock enforced
    writes to deal_inputs only -- creates new row, does not overwrite history
    updates deals.assumptions_snapshot_id to new row
    updates deals.updated_at and deals.row_version
    allowed keys: arv, ask_price, repair_estimate, mao, multiplier
    all fields numeric -- validated safely before insert
    omitted key = carry forward from base snapshot
    explicit null = remove key from assumptions
    same-value no-op = VALIDATION_ERROR
    missing base deal_inputs row = NOT_FOUND (no auto-create)
- No schema changes. No new tables. No existing RPCs modified.
- Tests: 10_11A7_deal_pricing_write_path.test.sql (16 tests, all pass)
- CONTRACTS.md sections 17, 17A, 59 updated
- rpc_contract_registry.json, execute_allowlist.json, definer_allowlist.json updated
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
Additive RPC only. No schema changes. No changes to existing RPCs.
Append-only deal_inputs pattern preserves pricing history.
Snapshot pointer kept in sync with new row.
No data loss -- base row preserved, new row created.

## Risk
Low. New RPC with append-only behavior.
deals.row_version incremented on success -- existing callers that check row_version
must be aware pricing edits also bump row_version.

## Rollback
Revert PR. Re-run supabase db push. No data migrations required.
Existing deal_inputs rows unaffected.