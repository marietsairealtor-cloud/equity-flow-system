# GOVERNANCE CHANGE — 10.11A6 Acquisition Backend — Deal Properties Write Path
UTC: 20260426T221336Z

## What changed
- Migration: 20260426000001_10_11A6_deal_properties_write_path.sql applied
- New RPC: update_deal_properties_v1(p_deal_id uuid, p_fields jsonb)
    SECURITY DEFINER, authenticated only, write lock enforced
    writes to deal_properties only -- does not touch deal_inputs or assumptions
    allowed keys: property_type, beds, baths, sqft, lot_size, year_built, occupancy,
      deficiency_tags, condition_notes, repair_estimate, garage_parking, basement_type,
      foundation_type, roof_age, furnace_age, ac_age, heating_type, cooling_type
    beds/baths/sqft/garage_parking treated as text (shorthand: 3+1, 2+1, 2400/1200)
    deficiency_tags: null=clear, array of strings=valid, else=VALIDATION_ERROR
    typed fields validated safely before UPDATE
    same jsonb patch semantics as update_deal_seller_v1
    missing deal_properties row returns NOT_FOUND (no auto-create)
- Tests: 10_11A6_deal_properties_write_path.test.sql (24 tests, all pass)
- CONTRACTS.md sections 17, 17A, 55, 58 updated
- rpc_contract_registry.json, execute_allowlist.json, definer_allowlist.json updated
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
Additive RPC only. No schema changes. No changes to existing RPCs.
Writes to deal_properties only -- deal_inputs and assumptions untouched.
repair_estimate in this item refers only to deal_properties.repair_estimate.
Same tenancy pattern as other write RPCs.

## Risk
Low. New RPC with no side effects beyond updating deal_properties and row_version.
No stage transitions. No activity log writes. No cascade effects.

## Rollback
Revert PR. Re-run supabase db push. No data migrations required.