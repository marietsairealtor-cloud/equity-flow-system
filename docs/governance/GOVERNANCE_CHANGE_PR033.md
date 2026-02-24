# Governance Change — PR033

## Trigger
Build Route 4.7 — Tier-1 Gate Surface Normalization (pre-implementation governance entry).

## Problem
Certain Tier-1 gates (e.g., truth-bootstrap) execute as steps within broader jobs rather than as standalone top-level jobs. Enforcement is technically correct but topology visibility is ambiguous — a gate buried inside a job is harder to audit, harder to reference in required_checks.json, and harder to reason about in ci_execution_surface.json.

## Decision
Add Build Route Item 4.7 to formalize normalization of the Tier-1 gate surface:
- Every Tier-1 CI gate declared in ci_execution_surface.json must be represented as a top-level merge-blocking job explicitly wired into the required aggregator.
- No logic changes — normalization only.
- No enforcement semantic changes.
- No required-check renames.

## Constraints
- Deterministic DoD and proof requirements established before implementation begins.
- No CI behavior modified at time of this governance entry.

## Authority
Build Route v2.4 Item 4.7. DEVLOG entry 2026-02-24.

## Risk
- Low. Pre-implementation governance recording only. No scripts, workflows, schema, or migrations touched.