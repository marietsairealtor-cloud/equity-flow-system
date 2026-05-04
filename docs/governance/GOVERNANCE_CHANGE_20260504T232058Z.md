# GOVERNANCE CHANGE — 10.12C1 Intake Backend — Manual Deal Creation + Draft Promotion
UTC: 20260504T232058Z

## What changed
- Migration: 20260505000001_10_12C1_intake_deal_creation_promotion.sql applied
- ALTER TABLE public.draft_deals ADD COLUMN promoted_deal_id uuid (FK to deals, ON DELETE SET NULL)
- ALTER TABLE public.intake_submissions ADD COLUMN draft_deals_id uuid (FK to draft_deals, 1:1 unique index)
- submit_form_v1 DROP + recreate (version 4): now persists draft_deals_id on intake row
- New internal helpers (REVOKE ALL from PUBLIC/anon/authenticated):
  - _intake_validate_pricing_assumptions_v1(jsonb)
  - _intake_apply_mao_to_assumptions_v1(jsonb)
  - _intake_validate_deal_property_jsonb_v1(jsonb)
- New RPC: create_deal_from_intake_v1(p_fields jsonb)
  - authenticated only, member+, write-lock enforced
  - creates real deals row with stage=new
  - atomic: deals + deal_inputs + deal_properties when supplied
  - MAO derived server-side
- New RPC: promote_draft_deal_v1(p_draft_id uuid, p_fields jsonb)
  - authenticated only, member+, write-lock enforced
  - promotes draft_deals row to real deals row with stage=new
  - merges draft fields with reviewed intake-user supplied fields
  - marks intake_submissions.reviewed_at = now()
  - duplicate promotion rejected via CONFLICT
  - atomic: deals + deal_inputs + deal_properties when supplied
- Tests: 10_12C1_intake_deal_creation_promotion.test.sql (20 tests, all pass)
- CONTRACTS.md §67 added
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered
- privilege_truth.json, execute_allowlist.json, rpc_contract_registry.json, definer_allowlist.json updated

## Why safe
- No existing RPC signatures changed except submit_form_v1 (same signature, additive column write)
- New RPCs are authenticated only -- no public surface expansion
- Internal helpers have no external grants
- Atomic writes prevent partial deal creation

## Risk
Low. Additive schema only. submit_form_v1 additive change (draft_deals_id write). New RPCs have no existing callers yet.

## Rollback
Revert PR. Re-run supabase db push.