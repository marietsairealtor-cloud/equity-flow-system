# Governance Change — PR060

## Build Route Item
Simplify completion tracking — eliminate manual completed_items.json

## What changed
Deleted docs/truth/completed_items.json (hand-maintained registry of completed Build Route items). Rewrote scripts/ci_qa_scope_coverage.ps1 to derive completed items deterministically from docs/proofs/manifest.json by parsing Build Route item IDs from canonical proof log filenames. No manual registry updates required. Coverage enforcement unchanged: every derived completed item must exist in qa_scope_map.json.

## Why safe
Completion source of truth moves from hand-authored JSON to machine-derived set from manifest (which is already robot-owned and proof-finalize controlled). The derived set matches the previous manual list exactly plus newer items (6.10, 6.11) that were already merged but not yet added to the manual registry — proving the new approach is strictly more accurate. No CI jobs added or removed. No gates weakened. Coverage enforcement logic unchanged.

## Risk
Low. If manifest filename conventions change, the regex parser would need updating. Convention is stable and enforced by proof:finalize. No other scripts depend on completed_items.json.

## Rollback
Restore completed_items.json from git history. Revert ci_qa_scope_coverage.ps1. No downstream impact.
