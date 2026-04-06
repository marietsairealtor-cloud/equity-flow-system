# GOVERNANCE CHANGE — 10.8.11H Workspace Farm Areas RPCs
UTC: 20260406T172418Z

## What changed
Corrective migration 20260406000001 rewrites all three farm area RPCs originally
authored in 10.8.6: list_farm_areas_v1, create_farm_area_v1, delete_farm_area_v1.
Key corrections: list role enforcement changed from admin to member per system
read/write pattern. All three migrated from json to jsonb return type. Error
envelopes corrected (data was null, now always object). Internal fields removed
from list response (tenant_id, row_version). id renamed to farm_area_id in all
responses. require_min_role_v1 moved to first executable statement. Added §44
and three §17 rows to CONTRACTS.md. Updated privilege_truth.json, qa_scope_map,
qa_claim, ci_robot_owned_guard. Updated 10.8.6 test file to match new shapes.

## Why safe
All three RPCs dropped and recreated per CONTRACTS §2 (signature/shape change).
No data loss — tenant_farm_areas table unchanged. All existing grants preserved
via explicit REVOKE ALL + GRANT sequence. 10.8.6 test file updated in same PR
to match new response shape. All 17 new tests and all 13 updated 10.8.6 tests
pass. No WeWeb calls directly to these RPCs yet — no frontend breakage.

## Risk
Medium. Three existing RPCs replaced. 10.8.6 tests updated in same PR — this
is permitted as a corrective contract alignment, not a governance violation.
Response shape change is intentional and QA-approved. farm_area_id replaces id
in all responses — any existing WeWeb bindings using id field will need updating
in 10.8.11I UI item.

## Rollback
Revert this PR. Run supabase db push to restore original 10.8.6 function bodies.
Revert 10.8.6 test file to original. No data loss. No migration dependencies.