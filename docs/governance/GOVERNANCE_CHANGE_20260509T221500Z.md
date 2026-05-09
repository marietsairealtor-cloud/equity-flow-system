# GOVERNANCE CHANGE — 10.12D1 Lead Intake UI — Internal Operator Queue (Phase 1 admin)

UTC: 20260509T221500Z

## What changed

Phase 1 (SOP **§Phase 1 — Implementation**) administrative closure for **Build Route 10.12D1**: contract and QA registry alignment for the authenticated WeWeb Lead Intake queue and review surfaces. **No new migrations or RPCs** in this governance slice — UI consumes existing **`§17`** / **`§64`** / **`§67`** / **10.12C8** paths only.

- **`docs/artifacts/CONTRACTS.md`** — **§68** documents **`/lead-intake`** and **`/lead-intake/new`** RPC wiring, **`draft_id`** pre-fill via **`get_draft_deal_v1`**, KPI date variables, and pointer to **`docs/ui-workflows/WORKFLOWS.md`** for workflow and variable names.
- **`docs/ui-workflows/WORKFLOWS.md`** — seven workflows and Lead Intake variables registered (**10.12D1**) — `fetch-intake-submissions`, `fetch-lead-intake-kpis`, `fetch-draft-deal-result`, `nav-to-new`, `promote-draft-deal`, `create-deal-from-intake`, `dismiss-submission`; **`submissions`**, **`leadintakeKpiData`**, **`draftDeal`**.
- **`docs/truth/qa_claim.json`** — active item **`10.12D1`**.
- **`docs/truth/qa_scope_map.json`** — **`10.12D1`** title + proof pattern **`^docs/proofs/10\.12D1_lead_intake_internal_ui_`**.
- **`scripts/ci_robot_owned_guard.ps1`** — finalized proof log filename pattern **`10.12D1_lead_intake_internal_ui_<UTC>.log`** (matches **BUILD_ROUTE_V2.4.md** proof line).

**Not in this slice:** **`docs/DEVLOG.md`** — authored under **Phase 5 — Review and Merge** per **SOP_WORKFLOW.md** after item closure.

## Alignment

- **Build Route `10.12D1`** — merge-blocking proof path **`docs/proofs/10.12D1_lead_intake_internal_ui_<UTC>.log`** (Phase 4 per **SOP_WORKFLOW.md**).
- **Prerequisites:** **`10.12C7`** merged (**`10.12C6`** draft read; earlier intake chain per Build Route).

## Why safe

Documentation and registry-only delta for the UI item; backend contracts unchanged in this slice.

## Risk

Low. Drift risk if WeWeb canvas changes without updating **WORKFLOWS.md** / **§68** — QA rejects workflow-only PRs without registry updates per **WORKFLOWS.md** header rule.

## Rollback

Revert this governance/doc/registry commit set; restore prior **`qa_claim.json`** active item if another lane owns the claim.
