# Governance Change PR072 — 7.8 Role Enforcement on Privileged RPCs

## What changed
Fixed inverted comparison in public.require_min_role_v1 (migration 20260304000001).
PostgreSQL enum order is owner(0) < admin(1) < member(2) so "more privileged = smaller".
Original check used v_role < p_min (wrong); corrected to v_role > p_min.
Added pgTAP test file 7_8_role_enforcement_rpc.test.sql with 12 tests: function
existence, enum ordering invariants, member/admin/owner truth table, catalog audit.

## Why safe
The fix corrects a security bug — the original function was rejecting owners and
admins from privileged operations rather than blocking members. No existing
production code called this function yet (no privileged RPCs exist). Correction
is safe with zero blast radius.

## Risk
Low. No privileged RPCs currently call require_min_role_v1. The fix makes the
guard correct for future use. pgTAP proves the truth table.

## Rollback
Revert migration 20260304000001 to restore original (incorrect) comparison.
Not recommended — original was a security bug.
