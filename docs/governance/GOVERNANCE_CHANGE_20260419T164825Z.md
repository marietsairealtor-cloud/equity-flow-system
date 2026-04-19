# GOVERNANCE CHANGE — 10.11 Acquisition Dashboard + Auto-Advance
UTC: 20260419T164825Z
PR Branch: main
PR HEAD SHA: d04eadb84afda4017908ca6dc7163882a32ec381

## Change Summary

Refined the Acquisition spec by splitting UI, backend, and wiring into separate Build Route items and aligning the WeWeb architecture to the latest Acq workflow and mockup decisions.

## Items Added / Modified

### Build Route
- Replaced prior mixed-scope Acquisition item with:
  - 10.11 — Acquisition Dashboard UI
  - 10.11A — Acquisition Backend
  - 10.11B — Acquisition Wiring
- Updated Acquisition flow assumptions to reflect:
  - owner-scoped Acq filters
  - Follow-ups as reminder-driven, not a stage
  - stage progression via valid next-step action buttons, not a generic status dropdown
  - Acq → Dispo handoff via assignee modal
  - reuse of existing MAO / reminder / logging / farm-area backend instead of rebuilding those systems inside 10.11A

### WEWEB_ARCHITECTURE
- Updated Acquisition page design / behavior to reflect the latest mockup decisions:
  - filter order: All, New, Analyzing, Offer Sent, Follow-ups, UC
  - Send to Dispo moved to header beside Copy deal summary
  - quick contact actions kept near Next action
  - seller/property info editable from section-level Edit actions
  - property edit handled via popup/modal with full property details
  - removed generic status dropdown concept
  - removed country-specific external listing links
  - removed close-angle and blocker sections
  - notes/log + reminders + activity log retained

## Rationale

The prior Acquisition item mixed UI, backend, and wiring into one scope bucket. That was harder to build, harder to review, and created unnecessary dependency friction.

The new split reflects the actual implementation order:
- build the page
- build the backend
- wire the page to the backend

The architecture was updated in parallel so the product spec matches the current Acq operating model instead of leaving the mockup and docs drifting apart.

## Why safe

This is a scope-clarification and implementation-sequencing change, not a product-direction change.

No new department, role model, or workflow engine was introduced.
Existing backend systems are reused where already defined:
- MAO
- reminder engine
- farm areas
- activity logging

The update reduces ambiguity by making Acquisition behavior explicit:
- what the page shows
- how stage movement works
- where editing happens
- how follow-up is calculated
- what belongs in UI vs backend vs wiring

## Risk

Main risk is reference drift if any later Section 10 items, prerequisites, proofs, or architecture notes still reference the old single Acquisition item shape.

Secondary risk is partial alignment if Build Route is updated but architecture text or mockup assumptions are not kept in sync.

There is also implementation risk if the coder treats notes as follow-up state; the intended design is reminder-driven follow-up, not note-driven follow-up.

## Rollback

If needed, revert the split and collapse 10.11 / 10.11A / 10.11B back into a single Acquisition item.

If needed, revert the corresponding WeWeb architecture changes at the same time so Build Route and architecture return to the same older version together.

Preferred rollback is not partial. Reverting only one document would reintroduce spec drift.
