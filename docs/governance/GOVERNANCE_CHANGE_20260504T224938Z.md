# GOVERNANCE CHANGE — Build Route 10.12C1 + WEWEB Architecture §4 intake alignment

UTC: 20260504T224938Z

## What changed

Documentation-only governance alignment for **scoped backend item 10.12C1** (manual deal creation + draft promotion) and for **WEWEB** public intake vs internal Lead Intake flows, consistent with **10.12B / 10.12C** as implemented and scoped.

### 1) `docs/artifacts/BUILD_ROUTE_V2.4.md`

- Inserted roadmap item **10.12C1 — Intake Backend — Manual Deal Creation + Draft Promotion** immediately after **10.12C** and before **10.12D**.
- Defines governed RPCs: `create_deal_from_intake_v1(p_fields jsonb)`, `promote_draft_deal_v1(p_draft_id uuid, p_fields jsonb)`.
- **Deliverable / DoD / Tests** cover: tenant-scoped real `deals` at stage `new`, draft promotion with merge + `intake_submissions.reviewed_at`, duplicate and cross-tenant rejection, workspace write lock, atomic writes across `deals` / `deal_properties` / `deal_inputs` / draft markers, authenticated member+ RPCs only, no WeWeb direct table access.
- **Proof:** `docs/proofs/10.12C1_intake_deal_creation_promotion_<UTC>.log`
- **Gate:** `merge-blocking`
- **Prerequisite:** `10.12C` merged

No runtime schema, RPC, or migration is introduced by this documentation change alone; implementation is tracked under **10.12C1** when built.

### 2) `docs/artifacts/WEWEB_ARCHITECTURE.md`

- **§4.2 Intake Form (Slug-Gated):** Corrected field lists to match **10.12B** public UI — seller **address, name, phone, email**; birddog **address, name, phone, email, condition notes, asking price**. Replaced obsolete MAO “pre-fill from public seller pricing” implication with **10.12C** contract language: seller public intake creates/updates tenant-scoped **draft** with **address-aligned** context; **`asking_price`, repair/condition-as-MAO inputs, and `timeline` are not captured from the public seller form** and remain **NULL** on the draft until governed non–public-intake paths populate them; buyer vs birddog side effects summarized.
- **New §4.3 Lead Intake page (Authenticated):** Documents **`/lead-intake`** — **Flow 1** manual entry / call-in → real deal **stage = `new`** via `create_deal_from_intake_v1`; **Flow 2** public submission review → promote **`draft_deals`** to real deal **stage = `new`** via `promote_draft_deal_v1`, with reviewed submission and duplicate rejection; states both RPCs must ship and be contract-tested **before** **10.12D** UI wires these actions; no direct table writes or client-only reviewed/deal logic.
- **Renumbered** former §4.3–4.5 to **§4.4–4.6** (Deal Viewer, URL Patterns, Slugs vs Tokens).
- **§4.5 URL Patterns** table: added **`/lead-intake`** row (authenticated, session).
- **§8.4 Lead Intake (Management):** Bullets reference **§4.3** flow 1 (real deal from internal entry) and flow 2 (draft promotion).
- **§8.6 Intake-to-MAO Pre-fill:** Rewritten so public seller forms do **not** supply pricing/repairs/condition-as-MAO/timeline; MAO pre-fill applies when those fields **exist on the draft** from **governed** sources, with address context after public seller intake when pricing columns are still NULL.

## Alignment references

- **BUILD_ROUTE** 10.12B (public form fields), **10.12C** (submission outcomes + draft/MAO contract), **10.12C1** (scoped RPC work), **10.12D** (Lead Intake UI — depends on backend readiness).
- **GUARDRAILS** §5 — no business logic duplicated in WeWeb for creation, promotion, or reviewed state beyond what **§4.3** allows after RPCs exist.

## Why safe

- **No database migrations, no new RPC implementations, no privilege or contract registry edits** in this change set.
- Updates **narrow** ambiguity (what public forms collect vs what backends own) and **add** explicit scope for upcoming **10.12C1** work and **10.12D** sequencing.

## Risk

**Low.** Documentation drift risk if future PRs update Build Route or WEWEB without keeping **10.12B / 10.12C / 10.12C1** language consistent.

## Rollback

Revert the PR that introduces this governance file and the associated edits to `BUILD_ROUTE_V2.4.md` and `WEWEB_ARCHITECTURE.md`. No data or production behavior to roll back.
