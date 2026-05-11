# GOVERNANCE CHANGE — Build Route v2.4 — Offer items 10.13B1 + 10.13C-D (rescope C/D)

UTC: 20260510T220000Z

## What changed

- **`docs/artifacts/BUILD_ROUTE_V2.4.md`** — after **`10.13B`**, inserted **`10.13B1`** (activity log copy correction for **`send_offer_v1`**). Replaced standalone **`10.13C`** (Formal PDF) and **`10.13D`** (UI wiring) with a single merged lane item **`10.13C-D`** (Send Offer + **`mailto:`** email delivery wiring). **`10.13E`** (Save Deal + Reopen Deal) was not modified.

## Alignment

- **Build Route** is the governance surface for delivery sequencing and DoD; this edit reflects mailto/email-offer delivery instead of formal PDF for the merged UI slice, and splits activity-log copy into a follow-on backend item **`10.13B1`** after **`10.13B`**.

## Why safe

- Documentation-only change to the build route artifact; no runtime, schema, or privilege changes in this record.

## Rollback

- Revert the **`BUILD_ROUTE_V2.4.md`** diff for this timestamp; restore prior **`10.13C`** / **`10.13D`** blocks if that sequencing is revived.
