# GOVERNANCE_CHANGE_PR042

## What changed
Gate script ci_definer_safety_audit.ps1 rewritten: scope restricted to public and rpc schemas only, allowlist cross-reference added, pg_proc.proconfig catalog check added per 6.2 hardened DoD, CI stub added. CI job definer-safety-audit added to ci.yml and wired into required. required_checks.json updated with CI / definer-safety-audit. completed_items.json, qa_claim.json, qa_scope_map.json updated to 6.2. ci_robot_owned_guard.ps1 allowlisted 6.2 proof log pattern.

## Why safe
Additive only. New merge-blocking gate added for application-owned SD functions in public and rpc schemas. System schemas explicitly excluded. CI stub registered in deferred_proofs.json — converts to live catalog check at 8.0.4. No existing gate weakened or removed. No policy changed.

## Risk
Low. Gate is additive. In CI the stub exits 0 unconditionally — no breakage risk until 8.0.4 conversion. Local gate scoped to public/rpc only — system SD functions unaffected.

## Rollback
Revert ci_definer_safety_audit.ps1 to prior version, remove definer-safety-audit job from ci.yml, remove CI / definer-safety-audit from required_checks.json, remove 6.2 from completed_items.json and qa_scope_map.json, remove 6.2 proof log pattern from ci_robot_owned_guard.ps1.