# GOVERNANCE CHANGE — Build Route v2.4 Addition — 10.8.11J
UTC: 20260405T192729Z

## What changed
Added Build Route item 10.8.11J (Update Display Name RPC + UI) to BUILD_ROUTE_V2_4.md.
Item covers update_display_name_v1 RPC and Profile Settings UI wiring for display name.
Additive only. No existing items modified. Identified as gap during 10.8.11G authoring
when list_workspace_members_v1 required display_name and user_profiles lacked the column.

## Why safe
Build Route addition is a planning document only. No schema changes in this PR.
No RPC changes in this PR. No gate logic changed. Individual item PR will carry
migration, tests, and proof. Lane-only gate — no merge-blocking impact.

## Risk
Low. Additive documentation only. No executable code changed. No migrations.
No existing CI gates affected. New item is lane-only gate only.

## Rollback
Revert this PR. No database state to undo. No generated artifacts affected.
Re-run npm run handoff to confirm zero diffs after revert.