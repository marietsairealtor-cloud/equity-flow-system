# Governance Change — PR056

## Build Route Item
2.16.5C Foundation Invariants Suite

## What changed
Upgraded scripts/foundation_invariants.mjs from stub-existence checker to structural validator running 5 invariant checks against generated/schema.sql: tenant isolation (current_tenant_id + RLS on tenant-owned tables), role enforcement (tenant_role enum + membership role column), entitlement truth compiles (GUARDRAILS §17 declaration), activity log write path (table + RPC), cross-tenant negative (no permissive policies + current_tenant_id enforced). CI job foundation-invariants already wired as required check — now executes real validation.

## Why safe
No migrations, RLS policies, privileges, or RPCs modified. Script reads generated/schema.sql and docs/artifacts/GUARDRAILS.md as inputs only. All validation is structural pattern matching against existing truth files. CI job already existed and was required — only the script body changed from stub to real checks.

## Risk
Low. False negatives possible if schema dump format changes, but schema.sql is robot-generated with stable pg_dump format. No false positives observed — all 5 checks pass on current schema.

## Rollback
Revert scripts/foundation_invariants.mjs to prior version. CI job continues to exist and pass (reverts to stub behavior).
