# Governance Change — PR115

## What changed

Build Route v2.4 Item 10.5 RPC Error Contract Tests. Merge-blocking.
pgTAP test file added: supabase/tests/10_5_rpc_error_contract_tests.test.sql
(40 tests). Tests verify error responses from public RPCs follow the frozen
envelope contract. CI job rpc-error-contracts added to ci.yml and
required.needs. required_checks.json regenerated via truth:sync.

## Tests added

create_deal_v1 (5 tests):
- CONFLICT (duplicate deal): ok=false, code=CONFLICT, data=null, error present
- NOT_AUTHORIZED: code=NOT_AUTHORIZED

update_deal_v1 (5 tests):
- CONFLICT (row version mismatch): ok=false, code=CONFLICT, data=null, error present
- NOT_AUTHORIZED: code=NOT_AUTHORIZED

create_share_token_v1 (15 tests):
- VALIDATION_ERROR null expires_at: ok=false, code=VALIDATION_ERROR, data=null, error present
- VALIDATION_ERROR past expires_at: code=VALIDATION_ERROR
- VALIDATION_ERROR >90d expires_at: code=VALIDATION_ERROR, error.fields present
- NOT_FOUND (deal not in tenant): ok=false, code=NOT_FOUND, data=null, error present
- CONFLICT (cardinality 50 tokens): ok=false, code=CONFLICT, data=null, error present
- NOT_AUTHORIZED: code=NOT_AUTHORIZED

revoke_share_token_v1 (5 tests):
- VALIDATION_ERROR null token: ok=false, code=VALIDATION_ERROR, data=null, error present
- NOT_AUTHORIZED: code=NOT_AUTHORIZED

lookup_share_token_v1 (10 tests):
- VALIDATION_ERROR null deal_id: ok=false, code=VALIDATION_ERROR, data=null, error present
- NOT_FOUND bad format (no existence leak): ok=false, code=NOT_FOUND
- NOT_FOUND nonexistent token: ok=false, code=NOT_FOUND
- NOT_AUTHORIZED: code=NOT_AUTHORIZED

## Why merge-blocking

Error contract is frozen per CONTRACTS.md §1. Any drift in error codes
or error envelope shape must be caught before merge.

## Why safe

Tests run in ROLLBACK transaction. Seed uses fixed UUIDs in a0500000-*
namespace. DO block seeds 50 share tokens for cardinality test — all
rolled back. No migrations introduced. No RPC signatures changed.

## Triple-registration

1. ci_robot_owned_guard.ps1: proof log path allowlisted
2. truth_bootstrap_check.mjs: N/A (no new truth files)
3. handoff.ps1: N/A (no new machine-derived files)

## Rollback

Remove supabase/tests/10_5_rpc_error_contract_tests.test.sql, remove
rpc-error-contracts from ci.yml and required.needs, run truth:sync,
open revert PR with governance file.