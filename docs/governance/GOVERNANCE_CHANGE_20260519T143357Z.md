# GOVERNANCE CHANGE -- 10.14B4A ACQ UI -- Health Dot Legend
UTC: 20260519T143357Z

## What changed
- ACQ deal list: health dot tooltip added to each deal card
- Tooltip shows on hover of the health dot trigger container (CSS :hover pattern)
- Tooltip text is driven by item.data.health_color:
  - green  -> Active
  - yellow -> Check in soon
  - red    -> Overdue
- Implementation: CSS :hover on wrapper container, tooltip child display:block on hover
- No workflows. No JavaScript state management. Browser-native hover.
- No backend change. No migration. No RPC change. No direct table calls.
- Existing health dots unchanged.
- WORKFLOWS.md not affected -- no workflow changes.

## Why safe
UI-only. CSS :hover is browser-native and per-card isolated inside the repeater.
No governed backend surface touched. No contract changes.

## Risk
Zero. Additive CSS only. No existing behavior changed.

## Rollback
Revert WeWeb publish. No DB or code changes to revert.