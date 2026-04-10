# GOVERNANCE CHANGE — 10.8.11J Update Display Name RPC + UI
UTC: 20260410T184245Z

## What changed
Added update_display_name_v1 RPC and corrected get_profile_settings_v1 for
10.8.11J:
- update_display_name_v1(p_display_name text): SECURITY DEFINER, authenticated
  only, updates user_profiles.display_name for auth.uid(); blank returns
  VALIDATION_ERROR; NOT_FOUND if no profile row exists
- get_profile_settings_v1 corrected to read display_name from user_profiles
  instead of returning hardcoded null
- Profile Settings UI wired: input loads from get_profile_settings_v1,
  save button calls update_display_name_v1
- CONTRACTS.md sections 49 added, section 17 updated, section 40 updated
- definer_allowlist.json, execute_allowlist.json, privilege_truth.json,
  rpc_contract_registry.json updated
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
No schema changes. No new columns. update_display_name_v1 uses auth.uid() only
— no cross-user updates possible. Blank validation enforced server-side.
get_profile_settings_v1 is a corrective internal logic fix only — interface
unchanged. No direct table calls from WeWeb. Lane-only gate.

## Risk
Low. New RPC is user-profile scoped only. No tenant boundary changes. No
privilege escalation. Corrective fix to get_profile_settings_v1 only changes
display_name from null to actual value — callers already handle this field.

## Rollback
Revert this PR. Drop update_display_name_v1. Re-run supabase db push to
restore get_profile_settings_v1 to previous version. No data migrations.
No schema rollback required.