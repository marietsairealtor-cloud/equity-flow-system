# FOUNDATION_BOUNDARY.md
Authoritative — Foundation vs Product/UI Boundary (Build Route 2.16.5A)

## Foundation (Owned Surface)
Foundation = governance + core DB security layer. Foundation owns:
- Tenancy model
- Memberships + roles
- Entitlement truth
- Activity log contract
- Baseline RLS policies + negative tests
- Core CI contracts/proofs

## Product/UI (Owned Surface)
Product/UI owns (must not weaken Foundation invariants):
- Product domain tables
- WeWeb pages and flows
- Product-specific views/functions extending baseline

## Enforcement (Policy)
- Any change to Foundation paths triggers merge-blocking governance gates.
- Product/UI changes must not weaken Foundation invariants.

## Notes
- This file defines the boundary only; enforcement mechanics live in CI and governance guards.
