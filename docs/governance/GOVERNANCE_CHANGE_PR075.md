# GOVERNANCE CHANGE — PR075

Date: 2026-03-05  
Author: <OPERATOR>

---

## What changed

This governance PR revises the Section 8 execution plan in `BUILD_ROUTE_V2.4.md` and updates the stub conversion triggers defined in `docs/truth/deferred_proofs.json`.

Section 8 is now split into staged conversions:

- 8.0 CI database infrastructure (Supabase start + DB smoke query)
- 8.0.1 clean-room-replay stub conversion
- 8.0.2 schema-drift stub conversion
- 8.0.3 handoff-idempotency stub conversion
- 8.0.4 definer-safety-audit stub conversion
- 8.0.5 pgtap + database-tests.yml stub conversion

The conversion triggers in `deferred_proofs.json` are updated so each stub gate is activated only when the required CI database infrastructure and prerequisite build-route items exist.

No enforcement surface is converted in this governance PR.  
This PR only changes the execution plan and trigger mapping.

---

## Why safe

This change is safe because it does not modify any existing enforcement behavior.

All stub gates remain stubbed after this PR.  
No CI job logic, database logic, or merge-blocking gates are altered.

The change only updates:

- the Build Route execution plan
- the trigger mapping in `deferred_proofs.json`

These updates ensure stub conversions occur in the correct order and only after CI database infrastructure exists. This preserves the Section 3.0 rule that each PR modifies exactly one enforcement surface.

---

## Risk

The primary risk would be misalignment between the updated trigger table and the future stub conversion PRs.

If the trigger mapping were incorrect, a stub gate could be converted before its prerequisites are satisfied. This could cause CI failures or partial enforcement.

However, the staged conversion order and explicit prerequisites listed in the Build Route significantly reduce this risk.

---

## Rollback

Rollback is straightforward.

If any issue arises, revert this governance PR.  
Reverting restores:

- the original Section 8 definition
- the original trigger mappings in `docs/truth/deferred_proofs.json`

Because this PR does not modify any CI jobs, database code, or enforcement surfaces, rollback has no side effects on system behavior.