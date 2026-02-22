# Governance Change — PR021

## What changed
- `docs/truth/secret_scan_patterns.json` — new hand-authored secret pattern registry (3 patterns)
- `scripts/proof_finalize.ps1` — hardened with pre-finalization secret scan
- `docs/artifacts/AUTOMATION.md` — documented secret scan step and pattern governance policy
- `docs/artifacts/SOP_WORKFLOW.md` — added Rule F documenting hardened proof:finalize behavior

## Why safe
- Secret scan runs before normalize or manifest write — no manifest pollution on match
- Prints pattern name and sanitized excerpt only — never exposes matched secret value
- Three structural patterns only — no entropy heuristics, no false positives on existing proofs
- False-positive regression confirmed: migration hashes, manifest SHA256s, UTC timestamps all PASS

## Decisions declared
- Pattern governance: new patterns require governance-change PR + false_positive_analysis field
- No entropy-based or generic base64 heuristics permitted

## Risk
- Low. Additive hardening to proof:finalize. Existing proofs unaffected (all clean against patterns).
- Downstream enforcement: proof-manifest fails if finalize is blocked (no manifest entry produced).

## Rollback
- Revert scripts/proof_finalize.ps1 to pre-3.9.5 version
- Remove docs/truth/secret_scan_patterns.json
- Revert AUTOMATION.md and SOP_WORKFLOW.md
- One PR, CI green, QA approve, merge