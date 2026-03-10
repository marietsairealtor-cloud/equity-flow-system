# Governance Change PR102 - 9.2 Expected Surface + Executable Allowlist Invariants

## What changed
Populated expected_surface.json with authoritative RPC surface.
Added ci_surface_invariants.mjs gate that hard-fails if DB surface,
OpenAPI surface, or execute_allowlist diverge from expected_surface.

## Invariants enforced
1. DB grants match expected_surface.rpc exactly.
2. OpenAPI surface is a subset of expected_surface.rpc.
3. execute_allowlist is a strict subset of expected_surface.rpc.

## Why safe
Read-only gate. No schema changes. Additive only. Hardens surface
visibility — any unintended RPC exposure or grant change will fail CI.

## Risk
Low. If a new RPC is added without updating expected_surface.json,
ci_surface_invariants will fail. This is the intended behavior.

## Rollback
Revert expected_surface.json to stub and remove ci_surface_invariants.mjs.
