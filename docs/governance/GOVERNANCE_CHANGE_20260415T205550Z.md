# GOVERNANCE CHANGE — 10.8.11R GitHub Actions Node 24 Runtime Compatibility
UTC: 20260415T205550Z

## What changed
- .github/workflows/*.yml: actions/checkout upgraded from @v4 to @v5 (Node 24)
- .github/workflows/*.yml: actions/setup-node upgraded from @v4 to @v6 (Node 24)
- supabase/setup-cli@v1 remains -- v2 does not exist, third-party limitation
- docs/artifacts/SOP_WORKFLOW.md: section 21 added documenting upgrades and
  known limitation for supabase/setup-cli@v1
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Result
Node 20 deprecation warning eliminated for actions/checkout and actions/setup-node.
Remaining warning for supabase/setup-cli@v1 is a confirmed third-party limitation.
Non-blocking until June 2, 2026 when GitHub forces Node 24 by default.

## Why safe
- Workflow-only changes
- No schema changes. No migrations. No RPC changes.
- actions/checkout@v5 and actions/setup-node@v6 are stable released versions
- No product logic changes

## Risk
Low. Workflow action version upgrades only.
If actions/checkout@v5 or actions/setup-node@v6 introduce breaking changes,
revert to previous versions in a hotfix PR.

## Rollback
Revert .github/workflows/*.yml action version references to previous versions.
No DB or schema rollback required.

## Future action
When supabase/setup-cli releases a Node 24 compatible version:
- Upgrade all supabase/setup-cli@v1 references in workflows
- Confirm Node 20 warning is fully eliminated
- Update SOP_WORKFLOW.md section 21 and toolchain.json
