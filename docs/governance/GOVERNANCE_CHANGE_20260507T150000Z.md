# GOVERNANCE CHANGE — WeWeb architecture + Build Route 10.12D (Lead Intake UI)

UTC: 20260507T150000Z

## What changed

- **`docs/artifacts/WEWEB_ARCHITECTURE.md`** — Lead Intake sections aligned with shipped backend **10.12C4** and with the **10.12D** UI scope:
  - **§4.2 / §4.3** — Review outcomes, **`mark_submission_reviewed_v1`** vs **`promote_draft_deal_v1`**, **`list_intake_submissions_v1`** (**unreviewed** seller/birddog only), **`get_lead_intake_kpis_v1`** field semantics (**`new_submissions`**, **`new_leads`**, **`rejected_count`**, **`submission_to_deal_pct`**, **`unreviewed_count`**, **`avg_review_time_hours`**).
  - **§8.4 / §8.7** — Lead Intake management + KPI strip rules: **RPC-only** (no WeWeb KPI math), default **Last 30 days** for strip, **`Unreviewed`** as queue badge only, no buyer roster on **`/lead-intake`**, empty state CTA, no hard-delete inbox UX.
  - **Prerequisite chain** — Documents that **10.12C1** / **10.12C4** must precede **10.12D** WeWeb wiring for promote / dismiss / list / KPI.
- **`docs/artifacts/BUILD_ROUTE_V2.4.md`** — **10.12D — Intake Ops — Lead Intake UI** is the **next** implementation item after **10.12C4** (backend review outcomes). Captures DoD for **`/lead-intake`**: KPI strip + badge, inbox via **`list_intake_submissions_v1`**, actions via **`mark_submission_reviewed_v1`** and **`promote_draft_deal_v1`**, management actions (form links / embed), proof path **`docs/proofs/10.12D_lead_intake_ui_<UTC>.md`**, gate **`lane-only`**, prerequisites **`10.12A`–`10.12C4`**.

## Alignment

- **CONTRACTS.md** §64 / §17 remain authoritative for RPC names and envelopes; **WEWEB_ARCHITECTURE** describes how WeWeb consumes those RPCs without table access or client-side business rules.
- **10.12D** stays out of **Dispo** buyer-roster scope (**10.14C**); buyer submissions remain off Lead Intake inbox per **10.12C3** / **10.12C4**.

## Why safe

- Documentation-only PR (no runtime schema change in this governance slice). UI work under **10.12D** remains governed by the same RPC and privilege rules as **10.12C4**.

## Risk

- Low for this doc commit. **10.12D** implementation must not introduce **`list_buyers_v1`** on **`/lead-intake`** or duplicate KPI math in the canvas.

## Rollback

- Revert this PR; restore prior **WEWEB_ARCHITECTURE** / **BUILD_ROUTE** text if product scope changes.
