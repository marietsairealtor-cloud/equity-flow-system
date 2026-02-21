# Governance Change — PR013

## What changed
- `docs/truth/qa_claim.json` — updated claimed Build Route item from 3.7 to 3.8
- `docs/artifacts/SOP_WORKFLOW.md` — revised SOP: added full execution procedure §1, clarified DEVLOG timing, added qa_claim.json to implementation checklist, semantic contract before green loop, other alignment fixes

## Why safe
- qa_claim.json update is a one-field truth file correction reflecting completed item 3.8
- SOP update is documentation-only — no scripts, migrations, or schema touched
- All changes are additive or clarifying; no existing enforcement surfaces removed

## Risk
- Low. SOP revision aligns documentation with observed practice from 3.8 execution.
- qa_claim.json is informational; no CI gate currently blocks on its value.

## Rollback
- Revert qa_claim.json to {"item": "3.7"}
- Revert docs/artifacts/SOP_WORKFLOW.md to prior version
- One PR, CI green, QA approve, merge