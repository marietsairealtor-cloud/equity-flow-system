# Governance Change — PR094

## What changed
Added pgTAP test file supabase/tests/8_5_share_surface_abuse_controls.test.sql proving anti-enumeration and replay controls on share link surface. Six tests: expired token deterministic failure, nonexistent/invalid tokens produce identical NOT_FOUND response shapes, cross-tenant isolation returns NOT_FOUND with identical shape. Updated truth bookkeeping (qa_claim, qa_scope_map, robot-owned guard).

## Why safe
Test-only addition. No schema changes, no migrations, no RPC changes. Tests validate existing behavior introduced in 6.7 and hardened in 8.4. No security surface modified.

## Risk
None. Read-only assertions against existing RPC behavior.

## Rollback
Remove test file and revert truth bookkeeping. Single-commit revert.