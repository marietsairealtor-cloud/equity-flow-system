## What changed
Added proof coverage for 10.8.7F (Pending Invite Resolution Invariants). Proves behavioral invariants of accept_pending_invites_v1() created in 10.8.7E. No migration changes unless invariant gap found. Registered in qa_claim.json, qa_scope_map.json, ci_robot_owned_guard.ps1.

## Why safe
Proof-only item. No schema changes. No RPC modifications. No new tables or functions. Existing accept_pending_invites_v1() behavior verified under invariant test suite.

## Risk
Low. Proof-only. No code changes unless invariant gap discovered during proof execution.

## Rollback
Revert PR. No DB changes to roll back.