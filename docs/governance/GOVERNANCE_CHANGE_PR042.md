# GOVERNANCE_CHANGE_PR042

## PR
pr/6.2-definer-safety-audit

## Date
2026-02-25

## Build Route Item
6.2 — SECURITY DEFINER Safety [HARDENED]

## Governance Surface Touched
- scripts/ci_definer_safety_audit.ps1 — gate rewritten: scope restricted to public/rpc, allowlist cross-reference added, proconfig catalog check added, CI stub added
- .github/workflows/ci.yml — definer-safety-audit job added, wired into required
- docs/truth/required_checks.json — CI / definer-safety-audit added
- docs/truth/completed_items.json — 6.2 added
- docs/truth/qa_claim.json — updated to 6.2
- docs/truth/qa_scope_map.json — 6.2 entry added
- scripts/ci_robot_owned_guard.ps1 — 6.2 proof log pattern allowlisted

## Nature of Change
Additive only. No gate weakened. No policy removed.
New merge-blocking gate added: definer-safety-audit.
Gate scoped to application schemas only (public, rpc).
CI stub registered per deferred_proofs.json; converts at 8.0.4.

## docs_only
false — governance-touching PR per GUARDRAILS §2.15

## Authority
Build Route v2.4 §6.2 (HARDENED)
GUARDRAILS §2.15 — governance-change guard