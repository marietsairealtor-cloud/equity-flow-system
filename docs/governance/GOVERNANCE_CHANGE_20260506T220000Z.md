# GOVERNANCE CHANGE — 10.12C4 Intake Backend — Submission Review Outcomes

UTC: 20260506T220000Z

## What changed

- Migration: **`20260507000001_10_12C4_submission_review_outcomes.sql`** (cloud-applied after QA).
- Schema: **`intake_submissions.review_status`**, **`review_outcome`** (+ constraints); legacy backfill documented in migration comments.
- RPC: **`mark_submission_reviewed_v1(p_submission_id uuid, p_outcome text)`** — authenticated only; member + **`current_tenant_id()`** before **`check_workspace_write_allowed_v1()`**; dismiss/reject outcomes; **`promoted`** rejected at RPC (promotion via **10.12C1** **`promote_draft_deal_v1`**).
- RPC updates: **`get_lead_intake_kpis_v1`** — **`new_submissions`**, **`new_leads`**, **`rejected_count`**, revised **`submission_to_deal_pct`** / **`unreviewed_count`** / **`avg_review_time_hours`** semantics per **10.12C4**.
- RPC updates: **`list_intake_submissions_v1`** — **`review_status = unreviewed`** only; items include **`review_status`**, **`review_outcome`**.
- Trigger: **`public.trg_draft_deals_promoted_sync_intake_review_v1`** on **`draft_deals.promoted_deal_id`** — sets linked intake reviewed + **`review_outcome = promoted`** (promote function body remains only in **10.12C1** migration).
- Tests: **`supabase/tests/10_12C4_submission_review_outcomes.test.sql`** (pgTAP; temp table **`_12c4_sid`** for id resolution under **`authenticated`**).
- **`docs/artifacts/CONTRACTS.md`** §17 mapping table + §64 — **`mark_submission_reviewed_v1`**, KPI/list/promote wording.
- Truth (Phase 1 manual where applicable): **`rpc_contract_registry.json`**, **`privilege_truth.json`**, **`execute_allowlist.json`**, **`definer_allowlist.json`**, **`write_path_registry.json`** (already aligned); **`qa_claim.json`**, **`qa_scope_map.json`**.

## Why safe

Additive intake review model; no direct table grants to app roles; writes remain RPC-only. Cross-tenant access returns **`NOT_FOUND`**.

## Risk

Low. KPI denominator/numerator semantics changed — consumers must use **10.12C4** payload fields.

## Rollback

Revert migration chain only per project rollback policy; requires coordinated app/client updates.
