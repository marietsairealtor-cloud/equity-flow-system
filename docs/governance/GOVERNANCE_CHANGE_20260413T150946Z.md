# GOVERNANCE CHANGE — 10.8.11N1 Workspace Write Lock Coverage Gate
UTC: 20260413T150946Z

## What changed
Added merge-blocking CI gate to enforce write lock coverage on all
workspace-write RPCs:
- scripts/ci_write_lock_coverage.ps1 added
- Gate checks authoritative in-scope RPC list for check_workspace_write_allowed_v1() call:
  create_deal_v1, update_deal_v1, create_farm_area_v1, delete_farm_area_v1,
  create_reminder_v1, complete_reminder_v1, create_share_token_v1,
  update_workspace_settings_v1, update_member_role_v1, remove_member_v1,
  invite_workspace_member_v1
- Gate checks inline-check RPCs for subscription enforcement:
  submit_form_v1, lookup_share_token_v1
- Gate fails with clear offending RPC names
- Job write-lock-coverage added to ci.yml
- write-lock-coverage added to required.needs in ci.yml
- docs/truth/required_checks.json updated via npm run truth:sync
- CONTRACTS.md section 17A updated with gate description
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
Gate is additive enforcement only. No schema changes. No RPC changes.
No migrations. Deterministic pass/fail based on authoritative RPC list.
Future write RPCs that miss the helper call will now fail CI automatically.
Merge-blocking gate.

## Risk
Low. Gate only reads migration files and checks for string presence.
False positives possible only if function body regex fails to parse --
WARN output in that case, not silent pass.

## Rollback
Remove job from ci.yml required.needs and delete script.
Run npm run truth:sync to update required_checks.json.