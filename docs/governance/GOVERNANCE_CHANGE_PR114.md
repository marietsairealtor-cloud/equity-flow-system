# Governance Change — PR114

## What changed

Build Route v2.4 Item 10.4 RPC Response Contract Tests. Merge-blocking.
pgTAP test file added: supabase/tests/10_4_rpc_response_contract_tests.test.sql
(25 tests). Tests verify list_deals_v1 and get_user_entitlements_v1 response
shapes match governed schemas in docs/truth/rpc_schemas/. CI job
rpc-response-contract-tests added to ci.yml and required.needs.
required_checks.json regenerated via truth:sync.

## Tests added

list_deals_v1 (12 tests):
- NOT_AUTHORIZED path: ok=false, code=NOT_AUTHORIZED, data=null,
  error present, error.message present, error.fields present
- OK path: ok=true, code=OK, error=null, data.items present,
  data.items is array, data.next_cursor=null

get_user_entitlements_v1 (13 tests):
- NOT_AUTHORIZED path: ok=false, code=NOT_AUTHORIZED, data=null,
  error present, error.message present, error.fields present
- OK path: ok=true, code=OK, error=null, data.tenant_id present,
  data.user_id present, data.is_member present, data.entitled present

## Why merge-blocking

RPC response shape is a frozen contract per CONTRACTS.md §1. Any drift
in response structure must be caught before merge. This gate enforces
that guarantee mechanically on every PR.

## Why safe

Tests run in ROLLBACK transaction — no persistent DB state. Seed data
uses fixed UUIDs in a0400000-* namespace to avoid conflicts with other
test files. No migrations introduced. No RPC signatures changed.

## Triple-registration

1. ci_robot_owned_guard.ps1: proof log path allowlisted
2. truth_bootstrap_check.mjs: N/A (no new truth files introduced)
3. handoff.ps1: N/A (no new machine-derived files)

## Rollback

Remove supabase/tests/10_4_rpc_response_contract_tests.test.sql, remove
rpc-response-contract-tests from ci.yml and required.needs, run truth:sync,
open revert PR with governance file.