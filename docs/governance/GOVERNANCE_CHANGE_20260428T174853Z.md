# GOVERNANCE CHANGE — 10.11A9 Acquisition Backend — Pricing Contract Correction
UTC: 20260428T174853Z

## What changed
- Migration: 20260428000003_10_11A9_pricing_contract_correction.sql applied
- Corrective to 10.11A7 -- revised update_deal_pricing_v1 contract
- Added assignment_fee to allowed keys
- Removed mao as client-writable key -- mao is now derived server-side
- MAO formula: (arv * multiplier) - repair_estimate - assignment_fee
- mao derived from post-merge snapshot -- respects explicit nulls/clears
- mao removed from new snapshot when any required input (arv, multiplier, repair_estimate) is missing after merge
- Also updated 10.11A7 test file: tests 7-8 updated to match new contract
- No schema changes. No new tables. No new columns.
- Tests: 10_11A9_pricing_contract_correction.test.sql (17 tests, all pass)
- CONTRACTS.md sections 17, 55, 59, 61 updated
- rpc_contract_registry.json, calc_version_registry.json updated
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
Corrective to existing RPC -- no new RPCs added.
mao was previously writable but never validated or enforced as derived.
Now mao is server-computed and consistent with the MAO calculator formula.
assignment_fee was always stored in assumptions but not writable via this RPC.
No data loss -- all existing deal_inputs rows preserved.
Append-only pattern unchanged.

## Risk
Medium. Behavior-breaking change to update_deal_pricing_v1:
- callers sending mao will now get VALIDATION_ERROR
- callers not sending assignment_fee will see it carried forward from base
Mitigated: WeWeb ACQ pricing edit popup updated to match new contract.

## Rollback
Revert PR. Re-run supabase db push.
Existing deal_inputs rows unaffected.