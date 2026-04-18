# GOVERNANCE CHANGE — 10.9 MAO Calculator (Server-Computed MAO)
UTC: 20260418T164430Z

## What changed
- Migration 20260418000001_10_9_mao_calculator.sql applied
- create_deal_v1(uuid, int, jsonb) revised -- signature unchanged
  require_min_role_v1('member') is first executable statement (guarded wrapper)
  All role-helper failures map to NOT_AUTHORIZED envelope
  check_workspace_write_allowed_v1() enforced after role check
  Safe numeric validation of arv, repair_estimate, desired_profit, multiplier
  MAO computed server-side: ROUND(arv * multiplier - repair_estimate - desired_profit)
  Frontend-supplied assumptions.mao unconditionally overwritten by backend value
  Backend-computed mao stored in deal_inputs.assumptions
  Backend-computed mao returned in response data
  p_id explicit null validation added
  REVOKE ALL FROM PUBLIC + GRANT TO authenticated
- rpc_contract_registry.json: create_deal_v1 updated to version 3, owner 10.9
- CONTRACTS.md: mapping table updated, section 54 added
- WEWEB_ARCHITECTURE.md: section 4.1 updated with dual-context rendering and
  backend-authoritative MAO save via create_deal_v1
- 6_3_tenant_integrity_suite.test.sql: updated to pass valid assumptions
- 7_9_tenant_context_integrity.test.sql: updated to pass valid assumptions
- 10_5_rpc_error_contract_tests.test.sql: updated to pass valid assumptions
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
- Signature unchanged -- no caller contract change
- Server-side MAO replaces frontend-trusted value -- more secure not less
- Validation is additive -- callers passing valid data are unaffected
- Role enforcement and write-lock enforcement added -- strengthens not weakens
- All existing tests updated to pass valid assumptions
- All 608 tests pass after migration

## Risk
Low-medium. create_deal_v1 is a core write path.
Mitigated by:
- Signature unchanged
- All tests pass
- Validation returns VALIDATION_ERROR not silent failure
- Role/write-lock enforcement is consistent with other workspace-write RPCs

## Rollback
Revert this PR. Run supabase db push to restore previous create_deal_v1.
No schema changes to roll back -- function body only.