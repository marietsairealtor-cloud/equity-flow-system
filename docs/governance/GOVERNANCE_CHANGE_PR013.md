# Governance Change — PR013

## What changed
- `docs/truth/qa_claim.json` — updated claimed Build Route item from 3.7 to 3.8
- `docs/truth/qa_scope_map.json` — added 3.8 entry with proof pattern for handoff-idempotency
- `docs/artifacts/SOP_WORKFLOW.md` — revised SOP: added full execution procedure §1, clarified DEVLOG timing, added qa_claim.json to implementation checklist, semantic contract before green loop, other alignment fixes

## Why safe
- qa_claim.json update reflects completed item 3.8
- qa_scope_map.json addition is additive — new entry only, no existing entries modified
- SOP update is documentation-only — no scripts, migrations, or schema touched

## Risk
- Low. SOP revision aligns documentation with observed practice from 3.8 execution.
- qa_scope_map.json addition enables qa-verify gate to recognize 3.8 proof logs.

## Rollback
- Revert qa_claim.json to {"item": "3.7"}
- Remove 3.8 entry from qa_scope_map.json
- Revert docs/artifacts/SOP_WORKFLOW.md to prior version
- One PR, CI green, QA approve, merge