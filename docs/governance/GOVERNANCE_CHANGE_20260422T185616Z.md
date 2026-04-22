# GOVERNANCE CHANGE — 10.11A2 Acquisition Backend — Seller / Property Edit Write Paths
UTC: 20260422T185616Z

## What changed
- Migration: 20260422000001_10_11A2_deal_edit_write_paths.sql applied
- New RPC: update_deal_seller_v1(p_deal_id uuid, p_fields jsonb)
    SECURITY DEFINER, authenticated only, write lock enforced
    jsonb payload: seller_name, seller_phone, seller_email, seller_pain, seller_timeline, seller_notes
    omit key = no change, explicit null = clear, same value = VALIDATION_ERROR
    empty/non-object payload = VALIDATION_ERROR, unknown keys = VALIDATION_ERROR
- New RPC: update_deal_property_v1(p_deal_id uuid, p_fields jsonb)
    SECURITY DEFINER, authenticated only, write lock enforced
    jsonb payload: address, next_action, next_action_due
    next_action_due validated as timestamptz before UPDATE
    same field contract as seller RPC
- No schema changes. No new tables. No changes to update_deal_v1.
- Tests: 10_11A2_deal_edit_write_paths.test.sql (27 tests, all pass)
- CONTRACTS.md sections 17, 17A, 57 updated
- rpc_contract_registry.json, execute_allowlist.json, definer_allowlist.json updated
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
Additive RPCs only. No schema changes. No changes to existing RPCs.
Both RPCs use jsonb IS DISTINCT FROM guard to prevent no-op mutations.
Both RPCs enforce workspace write lock per 10.8.11N.
Separate seller/property concerns per QA ruling -- update_deal_v1 unchanged.

## Risk
Low. New RPCs with no side effects beyond updating deal fields and row_version.
No stage transitions. No activity log writes. No cascade effects.

## Rollback
Revert PR. Re-run supabase db push. No data migrations required.