# Governance Change — PR017

## What changed
- `docs/artifacts/SOP_WORKFLOW.md` — Phase 1 Step 2: added `docs/truth/qa_scope_map.json` back to implementation checklist alongside `qa_claim.json`

## Why safe
- Documentation-only — no scripts, migrations, or schema touched
- Restores qa_scope_map.json to checklist, consistent with observed practice in 3.9.1

## Risk
- None. Single-line clarification to SOP checklist.

## Rollback
- Revert docs/artifacts/SOP_WORKFLOW.md to PR016 version
- One PR, CI green, QA approve, merge