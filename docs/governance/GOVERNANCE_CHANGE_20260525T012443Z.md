# GOVERNANCE CHANGE -- Nav Layout Revision -- Bottom Nav Removed + Top Nav Consolidated
UTC: 20260525T012443Z

## What changed
- Bottom Nav removed from all authenticated pages
- Top Nav component updated:
  - Hamburger menu now contains page navigation (Today, MAO, Lead Intake, ACQ, Dispo, TC)
  - Cog icon now contains settings (Switch Workspace, Workspace Settings, Profile Settings, Log out)
- Every authenticated page now uses this section structure:
  - Section: Subscription warning banner
  - Section (root): Error message component + Top Nav component + Page content container
- Section settings: width 100%, row gap 16px, padding 16px
- Top Nav visible when Supabase Auth['user'] !== undefined
- docs/artifacts/WEWEB_ARCHITECTURE.md updated: §6 Authenticated Shell revised
- docs/ui-workflows/WORKFLOWS.md updated: App Layout Convention section added

## Why
Bottom Nav caused persistent overlap with page content due to WeWeb section constraints.
Navigation consolidated into Top Nav hamburger menu -- cleaner, simpler, no positioning hacks.
Settings consolidated into cog icon -- clear separation from page navigation.

## Risk
Low. UI-only change. No backend changes. No RPC changes. No migration.

## Rollback
Revert WeWeb component changes. No repo rollback needed beyond this docs PR.