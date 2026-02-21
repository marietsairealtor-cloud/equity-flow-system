# Governance Change — PR014

## What changed
- `docs/artifacts/SOP_WORKFLOW.md` — three updates:
  1. Phase 1 Step 2: removed qa_scope_map.json from implementation checklist (qa_claim.json only)
  2. Phase 6 post-merge: added `npm run handoff` idempotency check after `npm run ship`
  3. Added §17 Section Close Verification procedure

## Why safe
- Documentation-only — no scripts, migrations, or schema touched
- Phase 6 addition formalizes the idempotency check proven by 3.8
- §17 adds a close procedure for major sections — additive only
- qa_scope_map.json removal from checklist reflects that it is updated as needed, not on every objective

## Risk
- Low. All changes are additive or clarifying.
- §17 adds new governance obligation (section close DEVLOG entry) but does not retroactively invalidate prior work.

## Rollback
- Revert docs/artifacts/SOP_WORKFLOW.md to PR013 version
- One PR, CI green, QA approve, merge