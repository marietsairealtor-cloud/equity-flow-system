## What changed
Added supabase/foundation/** and docs/artifacts/FOUNDATION_BOUNDARY.md to the governance-touch path matcher in docs/truth/governance_change_guard.json.

## Why safe
Closes a gap identified in audit. Foundation paths already exist in the repo but were not protected by the governance-change guard. No existing gates are removed or weakened. This is additive only.

## Risk
Low. Future PRs touching foundation paths will now correctly require a governance justification file. No current behavior is broken.

## Rollback
Revert the two path additions in docs/truth/governance_change_guard.json via a new PR.
