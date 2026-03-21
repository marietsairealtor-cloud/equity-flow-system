## What changed
Added tenant_invites table and accept_invite_v1 RPC via migration 20260321000001. Table is RPC-only (no RLS policies, REVOKE ALL). accept_invite_v1 is SECURITY DEFINER, validates app invite token, creates tenant membership idempotently. Registered in definer_allowlist, execute_allowlist, rpc_contract_registry, privilege_truth, CONTRACTS.md s32.

## Why safe
Additive only. New table and RPC. No existing RPCs or tables modified. RPC-only surface enforced - no direct table access possible. invited_by FK references auth.users not tenant_memberships.

## Risk
Low-medium. New core table tenant_invites. RPC-only access enforced. No direct grants. Membership creation is idempotent via accepted_at marker.

## Rollback
Revert PR. Drop tenant_invites table via compensating migration. Remove accept_invite_v1 RPC. Remove all registry entries.