# GOVERNANCE CHANGE — Build Route §10 roadmap reorganization and renumbering (10.12–10.32)

UTC: 20260503T174801Z

## Scope of change

This governance entry records a **documentation-only reorganization** of Build Route §10 in `docs/artifacts/BUILD_ROUTE_V2.4.md`.

The prior roadmap span **10.12–10.32** was replaced with a new grouped structure organized by operating flow:

- **10.12A–10.12D** — Intake + Forms
- **10.13A–10.13E** — Offer Flow + Save/Reopen
- **10.14A–10.14D** — Dispo + Share Packet
- **10.15A–10.15D** — TC
- **10.16A–10.16D** — Today + Notifications
- **10.17A–10.17E** — Shared UX + Shell Support
- **10.18A–10.18D** — Frontend Guards + E2E Verification

This replaces the previous flat / mixed sequencing with a backend-first, flow-aligned structure intended to reduce UI wiring churn and hidden backend gaps.

## Files changed

- **`docs/artifacts/BUILD_ROUTE_V2.4.md`**
  - Replaced legacy items **10.12–10.32**
  - Inserted reorganized items **10.12A–10.18D**
  - Updated prerequisite and cross-reference text where needed to point at the new numbering
- **Same file:** Updated **10.8.10 — Today View (Shell)** so task synthesis now references **10.16A** instead of legacy **10.25**

## New item inventory

### 10.12 — Intake + Forms
- **10.12A** — Intake Backend — Submission Persistence
- **10.12B** — Intake Forms — Public UI + Submit Wiring
- **10.12C** — Intake Backend — Submission Outcomes + MAO Pre-fill
- **10.12D** — Intake Ops — Lead Intake + Buyer Ops UI

### 10.13 — Offer Flow + Save/Reopen
- **10.13A** — Offer Backend — Data Contract + Soft Offer Copy
- **10.13B** — Offer Backend — Send Offer Write Path
- **10.13C** — Offer Output — Formal PDF
- **10.13D** — Offer Flow — UI Wiring
- **10.13E** — Offer Flow — Save Deal + Reopen Deal

### 10.14 — Dispo + Share Packet
- **10.14A** — Dispo Backend — Dashboard Data Contract + KPI Read Path
- **10.14B** — Dispo Backend — Share Link + Handoff Control
- **10.14C** — Dispo Share Packet — Deal Viewer + Share-Link Verification
- **10.14D** — Dispo — UI Wiring

### 10.15 — TC
- **10.15A** — TC Backend — Dashboard Data Contract + KPI Read Path
- **10.15B** — TC Backend — Checklist, Upload, Fee, and Return Paths
- **10.15C** — TC — UI Wiring
- **10.15D** — TC — Immutable Close Verification

### 10.16 — Today + Notifications
- **10.16A** — Today View — Data Contract + RPC
- **10.16B** — Today View — UI Wiring + Optimistic UI
- **10.16C** — Notifications — Drawer Data Contract + RPC
- **10.16D** — Notifications — Drawer UI Wiring

### 10.17 — Shared UX + Shell Support
- **10.17A** — Shared UX — Micro-Friction Bundle
- **10.17B** — Shared UX — Workspace Settings
- **10.17C** — Shared UX — Profile Settings Final Wiring
- **10.17D** — Shared UX — Error Pages + Friendly Expired Token
- **10.17E** — Shared UX — Quick-Copy Deal Summary + Context Links

### 10.18 — Frontend Guards + E2E Verification
- **10.18A** — Frontend Guard — RPC Contract Guard
- **10.18B** — Frontend Guard — Surface Enumeration Guard
- **10.18C** — Frontend Guard — Seat Enforcement UX + API Consistency
- **10.18D** — Frontend Verification — E2E WeWeb Wiring

## Legacy-to-new mapping summary

### Intake / forms
- **10.18.1** → **10.12B**
- **10.18.2** → **10.12A**
- **10.18.3** → **10.12C**
- **10.18.4** → **10.12C**
- **10.18.5** → **10.12B**
- **10.18.6** → **10.12D**
- **10.18.7** → **10.12D**
- **10.19** → **10.12C**

### Offer flow / save-reopen
- **10.12** → split across **10.13A**, **10.13B**, **10.13C**, **10.13D**
- **10.14** → **10.13E**

### Dispo / share packet
- **10.13** → split across **10.14A**, **10.14B**, **10.14D**
- **10.15** → **10.14C**
- **10.16** → **10.14C**

### TC
- **10.17** → split across **10.15A**, **10.15B**, **10.15C**, **10.15D**

### Today / notifications
- **10.25** → **10.16A**
- **10.25.1** → **10.16B**
- **10.31** → **10.16C**
- **10.32** → **10.16D**

### Shared UX / shell support
- **10.26** → **10.17A**
- **10.27** → **10.17B**
- **10.28** → **10.17C**
- **10.29** → **10.17D**
- **10.30** → **10.17E**

### Frontend guards / verification
- **10.20** → **10.18A**
- **10.21** → **10.18B**
- **10.22** → **10.18C**
- **10.23** → **10.18D**

## Legacy scope intentionally not carried into the rewritten span

- **10.24 — UI Gate Promotion Execution** is **not included** in the rewritten **10.12A–10.18D** span.
- If gate-promotion work remains in scope, it must be reintroduced explicitly under a new number or as a follow-on section item.

## What did not change

This governance change does **not** by itself introduce or approve:

- code changes
- database migrations
- RPC additions
- RPC removals
- privilege changes
- truth artifact changes under `docs/truth/**`
- CI workflow behavior changes
- runtime security posture changes
- UI behavior changes

This entry records **roadmap / traceability text only**.

## Why this change was made

The prior §10 sequencing mixed:

- backend contracts
- write paths
- UI wiring
- verification
- cross-cutting hardening

in a way that created execution churn, especially during large UI items where backend gaps were discovered mid-wiring.

The new structure groups work in the order the product actually flows:

1. Intake + Forms
2. Offer Flow
3. Dispo
4. TC
5. Today + Notifications
6. Shared UX / shell support
7. Frontend guards + E2E verification

This improves:

- prerequisite readability
- backend-before-UI sequencing
- ownership clarity by operating surface
- traceability from build item to proof artifact

## Safety rationale

This change is safe because it is limited to planning / governance text.

No runtime artifact is changed by renumbering or regrouping backlog items alone.

The only immediate effect is on:

- roadmap readability
- future implementation sequencing
- proof / traceability references

## Risks

### 1. Traceability drift
Legacy references to **10.12–10.32** may still exist in:
- older proof logs
- PR descriptions
- SOP notes
- handoff summaries
- reviewer comments

Those references may now point to superseded numbering and should be interpreted via the mapping above.

### 2. Missing carry-forward of legacy scope
Any legacy item not explicitly represented in the new structure may be accidentally dropped from execution scope.

Known watch item:
- legacy **10.24** is not represented in the rewritten **10.12A–10.18D** span

### 3. Prerequisite mismatch
New prerequisites introduced in the rewritten items must remain consistent with actual merged backend surfaces. Documentation errors here can create planning confusion even when runtime behavior is unchanged.

### 4. Transition-period confusion
During transition, some discussion and proof artifacts may use legacy numbering while new planning uses rewritten numbering. Teams must not assume those refer to different product scope without checking the mapping table.

## Required follow-up checks

After committing the Build Route rewrite, confirm:

- all internal references inside `BUILD_ROUTE_V2.4.md` point to the new numbering where applicable
- no stale reference to legacy **10.25** remains in Today-view planning text
- the new sequence contains no missing letter gaps within active grouped spans
- legacy **10.24** is either reintroduced explicitly or intentionally left out with no hidden dependency
- future proof files use the new numbering only

## Rollback

To roll back this documentation change:

1. Revert `docs/artifacts/BUILD_ROUTE_V2.4.md` to the prior version containing legacy items **10.12–10.32**
2. Restore any internal references changed to the new numbering
3. Remove this governance file only if no other committed artifact depends on the reorganization record

## Runtime impact

- **Runtime behavior:** none
- **Security impact:** none
- **Database impact:** none
- **Truth artifact impact:** none
- **CI impact:** none

## Result

Build Route §10 is now reorganized by operating flow and backend/UI split, with legacy **10.12–10.32** retired in favor of the new **10.12A–10.18D** roadmap structure.
