# GOVERNANCE CHANGE — 10.8.11E1 Workspace Slug Invariant Enforcement
UTC: 20260405T012030Z

## What changed
Added pgTAP test file 10_8_11E1_workspace_slug_invariant.test.sql proving that
tenant_slugs enforces UNIQUE(tenant_id) and UNIQUE(slug) behaviorally. Added
CONTRACTS.md §37 note confirming invariant is enforced and tested. Updated
qa_scope_map.json, qa_claim.json, and ci_robot_owned_guard.ps1 for proof registration.
No migration required — unique constraints already exist from 10.8.8B.

## Why safe
Test-only item. No schema changes. No new RPCs. No privilege changes. No migration.
Existing unique constraints confirmed present via SQL query against pg_indexes.
Tests run inside BEGIN/ROLLBACK — no persistent state. Additive governance only.

## Risk
Zero. No executable code changed. No database state altered. No existing gates
modified. Tests prove existing invariants already enforced at database level.

## Rollback
Revert this PR. No database state to undo. No migrations to reverse.
No dependent items affected.