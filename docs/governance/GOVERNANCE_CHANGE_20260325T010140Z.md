## What changed
Added accept_pending_invites_v1() RPC via migration 20260324000003. Resolves all valid pending invites for authenticated user by exact email match. No parameters. Oldest-first processing. Partial acceptance. Silent per-invite failure. Sets current_tenant_id only if NULL. Registered in definer_allowlist, execute_allowlist, rpc_contract_registry, privilege_truth, CONTRACTS.md s34.

## Why safe
Additive only. New RPC, no schema changes. No direct table grants. SECURITY DEFINER with fixed search_path. Email sourced from auth.users server-side only. accept_invite_v1 unchanged.

## Risk
Low. New RPC only. Idempotent membership creation via ON CONFLICT DO NOTHING. Silent failure prevents hard stops on partial invite sets.

## Rollback
Revert PR. Drop accept_pending_invites_v1 via compensating migration. Remove registry entries.