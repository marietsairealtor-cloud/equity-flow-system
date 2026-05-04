# GOVERNANCE CHANGE — 10.12C Intake Backend — Submission Outcomes + MAO Pre-fill
UTC: 20260504T205748Z

## What changed
- Migration: 20260504000001_10_12C_intake_submission_outcomes.sql applied
- ALTER TABLE public.draft_deals ADD COLUMN address text
- New internal helper: upsert_buyer_from_intake_v1(p_resolved_tenant uuid, p_payload jsonb)
  - SECURITY DEFINER, REVOKE ALL from PUBLIC/anon/authenticated
  - Exempt from role/write-lock enforcement (called only from anon-capable submit_form_v1)
  - Dedupe: email match (lower-normalized) first; phone fallback only when email absent
  - Email present + no match = new record (no phone merge)
  - Safe deal_type_tags parsing (jsonb_typeof guard)
- submit_form_v1 DROP + recreate (version 3, build_route_owner 10.12C):
  - Seller path: stores address only; asking_price/repair_estimate always NULL from public intake
  - Buyer path: calls upsert_buyer_from_intake_v1, returns buyer_id in data envelope
  - Birddog path: intake record only, no side effects
- Also updated: 10_8_1_slug_system.test.sql -- test 21 updated to assert pricing NULL
- Also updated: 10_12A_intake_submission_persistence.test.sql -- test 20 uses actual row count
- Tests: 10_12C_intake_submission_outcomes.test.sql (22 tests, all pass)
- CONTRACTS.md §66 added
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered
- privilege_truth.json, rpc_contract_registry.json, definer_allowlist.json updated

## Why safe
- No existing RPC signatures changed (submit_form_v1 same signature)
- Seller intake pricing fields set to NULL explicitly -- no data loss
- Buyer upsert is additive -- creates or updates intake_buyers only
- Birddog path unchanged
- Internal helper has no external grants

## Risk
Low. Additive schema (address column). submit_form_v1 logic preserved; pricing
fields were already NULL for buyer/birddog paths in 10.12A.

## Rollback
Revert PR. Re-run supabase db push. intake_buyers rows created in this window
are lost on rollback.