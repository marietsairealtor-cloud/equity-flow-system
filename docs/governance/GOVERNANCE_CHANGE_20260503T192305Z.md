# GOVERNANCE CHANGE — 10.12A Intake Backend — Submission Persistence
UTC: 20260503T192305Z

## What changed
- Migration: 20260503000001_10_12A_intake_submission_persistence.sql applied
- New tables:
  - public.intake_submissions (tenant_id, form_type, payload, source, submitted_at, reviewed_at)
  - public.intake_buyers (tenant_id, name, email, phone, areas_of_interest, budget_range, deal_type_tags, price_range_notes, notes, is_active)
- Both tables: REVOKE ALL from anon/authenticated, RLS enabled with USING+WITH CHECK, indexes on (tenant_id, submitted_at/created_at DESC, id DESC)
- submit_form_v1(p_slug, p_form_type, p_payload): DROP+recreate to also write intake_submissions row on every successful submission. All 10.8.11N logic preserved (slug validation, spam token, subscription block, draft_deals insert, seller MAO pre-fill). Return type changed json->jsonb. Subscription query made deterministic (ORDER BY created_at DESC LIMIT 1). Safe numeric cast via NULLIF.
- New: list_intake_submissions_v1(p_limit int) -- authenticated, tenant-scoped
- New: list_buyers_v1(p_limit int) -- authenticated, tenant-scoped
- Tests: 10_12A_intake_submission_persistence.test.sql (21 tests, all pass)
- CONTRACTS.md §64 added
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1, privilege_truth.json, execute_allowlist.json, rpc_contract_registry.json updated

## Why safe
- submit_form_v1 existing callers unaffected: same signature, same validation, same draft_deals write, intake_submissions write is additive
- SECURITY DEFINER functions write tables directly; authenticated role cannot access tables directly
- No changes to existing RPC signatures

## Risk
Low. Additive schema only. No existing table modified. submit_form_v1 logic preserved exactly; intake_submissions write is append-only after successful draft_deals insert.

## Rollback
Revert PR. Re-run supabase db push. intake_submissions and intake_buyers rows created in this window are lost on rollback.