# GOVERNANCE CHANGE — 10.8.11I Workspace Settings UI
UTC: 20260407T222219Z

## What changed
Completed WeWeb Workspace Settings UI page. Three tabs: General, Members, Farm
Areas. General tab includes workspace identity fields (name, slug, country,
currency, measurement unit) wired to update_workspace_settings_v1, plus owner-only
billing section with Stripe portal link. Members tab includes member list with role
display, role change dropdown, remove member, and invite member form. Farm Areas
tab includes farm area list with add and delete. Page is admin+ only — members
cannot access. Hamburger popup Workspace Setting link hidden from members via
entitlements role check. Updated qa_scope_map.json, qa_claim.json, and
ci_robot_owned_guard.ps1 for proof registration.

## Why safe
WeWeb-only item. No migrations. No RPC changes. No schema changes. No new RPCs.
All data calls via existing allowlisted RPCs only. No direct table access from
WeWeb. Role gating enforced server-side by RPCs. UI visibility checks are display
only — not relied on for security. Lane-only gate.

## Risk
Low. Frontend-only changes. No backend state affected. No existing RPCs modified.
Billing section owner-only gating enforced via entitlements.data.role check on
display binding — not rendered for non-owners.

## Rollback
Revert this PR. No database state to undo. WeWeb changes are independent of
backend. No dependent items blocked by this page existing or not.