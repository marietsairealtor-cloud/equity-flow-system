# Governance Change PR074 — SOP §1 Gate Pre-checks + §18 Known Gate Behaviors

## What changed
Added two gate pre-check bullets to SOP_WORKFLOW.md §1 Phase 1 Step 2:
- Migrations containing calc-logic tokens must pre-emptively update
  calc_version_registry.json in the same commit (do not wait for
  ci_calc_version_lint to fail in CI).
- Migrations that change schema must pre-emptively add a substantive note to
  CONTRACTS.md (do not wait for ci_entitlement_policy_coupling to fail in CI).

Added new §18 Known Gate Behaviors with two subsections:
- §18.1: ci_calc_version_lint — why it over-triggers, prescribed fix.
- §18.2: ci_entitlement_policy_coupling — why it over-triggers, prescribed fix.

## Why safe
Documentation-only change. No migrations, schema, RPC, CI behavior, or truth
file changes. Adds operational guidance to prevent recurring gate failures
observed during Build Route items 7.8 and 7.9.

## Risk
None. SOP additions only. No behavioral change to any gate or production code path.

## Rollback
Revert the two bullet points from §1 Phase 1 and delete §18 via a single
governance PR.
