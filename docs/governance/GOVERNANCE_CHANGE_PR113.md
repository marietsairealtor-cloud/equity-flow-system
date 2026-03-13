# Governance Change — PR113

## What changed

Build Route v2.4 Item 10.3 RPC Response Schema Contracts. Lane-only per
Section 10 scope-control policy. Governed schema files created for two
public RPCs: list_deals_v1 and get_user_entitlements_v1. Schema files
define envelope structure, success response payload, error responses,
field types, and nullability. Schema files are truth-registered and
bootstrap-validated.

## Files introduced

- docs/truth/rpc_schemas/list_deals_v1.json (version 1)
- docs/truth/rpc_schemas/get_user_entitlements_v1.json (version 1)

## Why safe

No migrations, no schema changes, no RPC signature changes, no Foundation
paths touched. No CI gate wired — lane-only. Schema files are read-only
truth artifacts. They do not affect runtime behavior. They establish the
governed baseline that 10.4 (RPC Response Contract Tests) will validate
against.

## Schema change governance

Any change to a governed RPC response schema requires a governance PR.
Schema version must be incremented. Rationale must be documented.
Downstream contract tests (10.4) must be updated in the same PR.

## Triple-registration

1. ci_robot_owned_guard.ps1: proof doc path allowlisted
2. truth_bootstrap_check.mjs: both schema files in required array
3. handoff.ps1: N/A (hand-authored files, not machine-derived)

## Risk

None. Read-only truth files. No runtime behavior changes.

## Rollback

Remove docs/truth/rpc_schemas/ directory and revert truth_bootstrap_check.mjs
and ci_robot_owned_guard.ps1 changes via follow-on PR.