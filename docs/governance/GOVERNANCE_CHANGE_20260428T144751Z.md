# GOVERNANCE CHANGE — 10.11A8 Acquisition Backend — Repair Estimate Source-of-Truth Cleanup
UTC: 20260428T144751Z

## What changed
- Migration: 20260428000002_10_11A8_repair_estimate_cleanup.sql applied
- Updated update_deal_properties_v1 to remove repair_estimate from allowed keys
- repair_estimate now returns VALIDATION_ERROR from update_deal_properties_v1
- update_deal_pricing_v1 is sole owner of repair_estimate in ACQ flow
- deal_properties.repair_estimate column left in place but no longer written by ACQ flow
- No schema changes. No new tables. No new columns.
- Tests: 10_11A8_repair_estimate_cleanup.test.sql (8 tests, all pass)
- CONTRACTS.md sections 17, 55, 58, 60 updated
- rpc_contract_registry.json updated
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
Behavior-breaking change to update_deal_properties_v1 is intentional cleanup.
repair_estimate was previously writable via both property and pricing paths.
Now only pricing path (update_deal_pricing_v1) writes repair_estimate.
No data loss -- deal_properties.repair_estimate column preserved.
No other RPCs modified.

## Risk
Low-medium. Any caller passing repair_estimate to update_deal_properties_v1 will now
get VALIDATION_ERROR. Mitigated: WeWeb ACQ property edit popup must not send
repair_estimate -- confirmed removed from UI save action in 10.11B.

## Rollback
Revert PR. Re-run supabase db push.