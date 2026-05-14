# GOVERNANCE CHANGE -- 10.14B1 Dispo Backend -- Buyer Active Status Mutation
UTC: 20260513T234717Z

## What changed
- Migration: 20260517000001_10_14B1_buyer_active_status_mutation.sql applied
- New RPC: update_buyer_active_status_v1(p_buyer_id uuid, p_is_active boolean)
- Updates intake_buyers.is_active for a tenant-scoped buyer
- No new tables. No signature change to list_buyers_v1.
- Tests: 10_14B1_buyer_active_status_mutation.test.sql (9 tests, all pass)
- CONTRACTS.md updated
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
Single RPC addition. No schema changes. No table additions.
Existing list_buyers_v1 unchanged. No privilege escalation.
SECURITY DEFINER with require_min_role_v1 member guard.
Tenant-scoped -- cross-tenant access returns NOT_FOUND.

## Risk
Low. Additive only. No existing RPC modified.

## Rollback
Revert PR. No data migration needed.