# Governance Change — PR116

## What changed

Build Route v2.4 Item 10.6 RPC Contract Registry. Merge-blocking.
New truth file: docs/truth/rpc_contract_registry.json (version 1) —
9 entries covering all public RPCs in expected_surface.json and
execute_allowlist.json. New verifier script: scripts/ci_rpc_contract_registry.mjs.
CI job rpc-contract-registry added to ci.yml and required.needs.
scripts/ci_semantic_contract.mjs updated to allowlist npm run rpc-contract-registry.
required_checks.json regenerated via truth:sync.

## Registry entries

create_deal_v1, create_share_token_v1, current_tenant_id,
foundation_log_activity_v1, get_user_entitlements_v1, list_deals_v1,
lookup_share_token_v1, revoke_share_token_v1, update_deal_v1.

Each entry contains: name, version, build_route_owner, input_contract,
response_schema (null or file path), error_codes, notes.

## CI checks enforced

1. Every RPC in expected_surface.json exists in registry
2. Every RPC in execute_allowlist.json exists in registry
3. Every response_schema reference points to an existing file
4. Every registry entry has all required fields

## Why merge-blocking

Any new RPC added to the surface or allowlist must have a governed
contract record before it can merge. Prevents undocumented RPCs from
reaching production.

## Triple-registration

1. ci_robot_owned_guard.ps1: proof log path allowlisted
2. truth_bootstrap_check.mjs: rpc_contract_registry.json added to required array
3. handoff.ps1: N/A (hand-authored file, not machine-derived)

## ci_semantic_contract.mjs edit

npm run rpc-contract-registry added to hasAllowlistedGate allowlist.
This is a product-layer script edit — not robot-owned. Required to
allow the new gate to pass ALLOWLISTED_GATE check. Confirmed RESULT=PASS
after edit.

## Rollback

Remove docs/truth/rpc_contract_registry.json, scripts/ci_rpc_contract_registry.mjs,
remove rpc-contract-registry from ci.yml and required.needs, revert
truth_bootstrap_check.mjs and ci_semantic_contract.mjs changes,
run truth:sync, open revert PR with governance file.