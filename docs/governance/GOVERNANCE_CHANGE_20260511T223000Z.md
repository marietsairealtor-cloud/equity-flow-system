# GOVERNANCE CHANGE — Build Route 10.13C-D Offer UI — Send Offer + Email Delivery Wiring (Phase 1 admin)

UTC: 20260511T223000Z

## What changed

- **`docs/artifacts/CONTRACTS.md`** — **§17** mapping rows for **`get_offer_payload_v1`**, **`refresh_deal_soft_offer_v1`**, **`send_offer_v1`**: add **10.13C-D** UI consumption notes (Offer Sent sequence, optional **`mailto:`** body via **`get_offer_payload_v1`** when explicitly bound). **§63** Acquisition wiring: **Offer Sent** + **Email Offer** behavior; **§Registry** line lists **`acq-offer-sent`** / **`acq-email-offer`**.
- **`docs/ui-workflows/WORKFLOWS.md`** — new workflows **`acq-offer-sent`** and **`acq-email-offer`**; **ACQ Page Variables** registry rows (**`acqOfferSendRefreshKey`**, **`acqOfferSendCommitKey`**, **`offerPayload`**).
- **`docs/artifacts/WEWEB_ARCHITECTURE.md`** — Acquisition **Actions** / **Data** aligned to governed offer send + **`mailto:`** email offer; **§3** deal-stage auto-advance note; **§8.5** Offer Generator vs Acquisition lane distinction; **§7.4** Send Offer routing.
- **`docs/truth/qa_claim.json`** — active item **`10.13C-D`**.
- **`docs/truth/qa_scope_map.json`** — **`10.13C-D`** title + proof pattern **`^docs/proofs/10\.13C-D_offer_ui_send_email_wiring_`**.
- **`scripts/ci_robot_owned_guard.ps1`** — allowlist for **10.13C-D** lane proof **`.md`** filename pattern.

## Alignment

- **Build Route `10.13C-D`** (**`docs/artifacts/BUILD_ROUTE_V2.4.md`**): prerequisites **`10.13A`**, **`10.13B`** merged; **Proof** path **`docs/proofs/10.13C-D_offer_ui_send_email_wiring_<UTC>.md`**; **Gate** **`lane-only`**. This change set is **Phase 1 (SOP)** documentation and QA registry alignment only — **no** new migrations, RPCs, or WeWeb canvas edits.

## Why safe

- Contract text documents existing **§69–§70** RPCs already merged; UI registry entries are authoritative placeholders until canvas wiring lands in a follow-up PR.

## Risk

- Low. Docs-only; operators must still implement WeWeb graphs to match **`WORKFLOWS.md`**.

## Rollback

- Revert this governance file and the listed doc/script edits on the PR branch.
