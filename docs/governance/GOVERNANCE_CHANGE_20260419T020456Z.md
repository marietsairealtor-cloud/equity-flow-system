# GOVERNANCE CHANGE — 10.11 Acquisition Dashboard + Auto-Advance
UTC: 20260419T020456Z
PR Branch: main
PR HEAD SHA: 13263a003c4bb18e14cf09e2f019ad515dd6fb30

## Change Summary

Aligned the product spec across both documents by restructuring the intake/forms section, adding explicit buyer-flow and notifications items, and updating the WeWeb architecture to match the new Build Route scope and page responsibilities.

## Items Added / Modified

### Build Route
- Replaced old single-item 10.18 with a section container:
  - 10.18 — Intake Forms + Intake Operations
- Added:
  - 10.18.1 — Public Intake Form Surface
  - 10.18.2 — Intake Submission Persistence Backend
  - 10.18.3 — Seller Intake → Draft Deal Backend
  - 10.18.4 — Buyer Intake → Buyer Records Backend
  - 10.18.5 — Public Intake Form Submit Wiring
  - 10.18.6 — Lead Intake Management UI
  - 10.18.7 — Buyer List + Quick Filters + Manual Send Workflow
- Added notifications items:
  - 10.31 — Notifications Drawer Data Contract + RPC
  - 10.32 — Notifications Drawer UI Wiring

### WEWEB_ARCHITECTURE
- Updated architecture to reflect the same intake/forms decomposition
- Updated architecture to reflect lean buyer handling:
  - buyer records
  - quick filters
  - manual send workflow
  - no buyer-deal matching engine
- Updated architecture to include notifications drawer behavior and ownership
- Kept page responsibilities aligned with the revised Build Route scope

## Rationale

The prior intake/forms scope was too vague. It mixed public forms, submission handling, seller draft-deal creation, buyer handling, and internal intake operations into one blob. That created build ambiguity and backend gaps.

The new split makes the system explicit and buildable in the correct order:
public forms → backend persistence → seller path → buyer path → wiring → internal ops UI → buyer ops.

The WeWeb architecture also needed to be updated so the product spec did not diverge between:
- what Build Route says must be built
- what the architecture says the product is

Notifications were already implied in the shell through the bell, but they were not clearly defined as backend + UI items. 10.31 and 10.32 close that gap.

## Why safe

This is a scope-clarification and spec-alignment change, not a product-direction change.

It does not introduce:
- buyer-deal matching logic
- buyer CRM / Rolodex expansion
- direct-table frontend access
- enterprise workflow complexity

It makes the intended product behavior explicit across both governing docs:
- public seller / buyer / birddog forms
- governed backend submission path
- seller submissions flowing into draft deals
- buyer submissions flowing into lean buyer records
- internal lead-intake operations
- manual buyer filtering / send workflow for small teams
- notifications drawer backend + UI

This reduces ambiguity and lowers implementation risk.

## Risk

Main risk is reference drift if any later Build Route items, architecture sections, proofs, or prerequisites still point to the old single-item 10.18 structure or old buyer-flow wording.

Secondary risk is document divergence if future edits update Build Route without updating WEWEB_ARCHITECTURE, or vice versa.

Notifications also add a governed RPC/data surface, so contract registry / allowlist / proof references must stay aligned.

## Rollback

If needed, revert the Build Route changes by collapsing 10.18.1–10.18.7 back into the prior single 10.18 item and remove 10.31 / 10.32.

If needed, revert the matching WEWEB_ARCHITECTURE edits so both docs return to the prior structure together.

Preferred rollback is not full removal, but restoring one consistent older version across both documents. Partial rollback of only one file is not safe because it would reintroduce spec drift between architecture and build instructions.