# GOVERNANCE CHANGE -- 10.14B2 Dispo Backend -- Deal Milestone Timestamp Mutation
UTC: 20260517T141230Z

## What changed
- Migration: 20260517000002_10_14B2_dispo_deal_milestone_mutation.sql applied
- New RPC: set_dispo_deal_milestone_v1(p_deal_id uuid, p_milestone text, p_is_complete boolean)
- Sets or clears assignment_agreement_signed_at / earnest_money_received_at on dispo deals
- Writes deal_activity_log on every successful mutation
- No new tables. No signature change to existing RPCs.
- Tests: 10_14B2_dispo_deal_milestone_mutation.test.sql (19 tests, all pass)
- CONTRACTS.md updated
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
Single RPC addition. No schema changes beyond reuse of existing columns added in 10.14B.
No new tables. Existing handoff_to_tc_v1 unchanged.
SECURITY DEFINER with require_min_role_v1 member guard.
Tenant-scoped -- cross-tenant access returns NOT_FOUND.
Only dispo-stage deals can be mutated.

## Risk
Low. Additive only. No existing RPC modified.

## Rollback
Revert PR. No data migration needed.