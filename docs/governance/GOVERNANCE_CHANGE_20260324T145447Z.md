## What changed
Modified accept_invite_v1 via migration 20260324000001 to set user_profiles.current_tenant_id after invite acceptance. No schema changes. Registered in CONTRACTS.md s33, ci_robot_owned_guard.ps1, qa_claim.json, qa_scope_map.json.

## Why safe
Additive behavioral fix only. No new tables, columns, or RPCs. Upsert is idempotent. tenant_id sourced from invite row (server-side only). Completes tenancy contract from 10.8.7C.

## Risk
Low. Single RPC behavior change. Idempotent upsert. No privilege changes.

## Rollback
Revert PR. Prior accept_invite_v1 behavior restored via compensating migration.