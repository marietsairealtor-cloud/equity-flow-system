# Governance Change — PR022

## What changed
- `docs/artifacts/AUTOMATION.md` — added stub-active proof acknowledgment: while deferred_proofs.json is non-empty, proof logs must include a STUB_GATES_ACTIVE block per SOP Rule F
- `docs/artifacts/SOP_WORKFLOW.md` — added Rule F: STUB_GATES_ACTIVE block mandatory in proof logs while stub gates are active; lists every active stub by name and conversion_trigger
- `docs/truth/deferred_proofs.json` — added _proof_authoring_requirement field documenting the STUB_GATES_ACTIVE block obligation inline
- `docs/DEVLOG.md` — advisor review entry (Section 4 entry readiness + 8.0 stub conversion strategy) + Build Route modification entries per SOP §14
- `docs/artifacts/BUILD_ROUTE_V2.4.md` — updates per advisor review findings (recorded in DEVLOG)

## Authority
Three-advisor review 2026-02-22. Decisions grounded against Build Route v2.4, CONTRACTS.md, GUARDRAILS.md, AUTOMATION.md, SOP_WORKFLOW.md.

## Why safe
- Documentation and operator authoring requirement only — no CI enforcement surface added
- deferred_proofs.json _proof_authoring_requirement field is informational — registry schema unchanged
- No scripts, migrations, or schema touched

## Risk
- Low. Adds operator authoring obligation for proof logs while stubs are active.
- CI does not enforce STUB_GATES_ACTIVE block presence — deferred-proof-registry remains the machine enforcement layer.

## Rollback
- Revert AUTOMATION.md, SOP_WORKFLOW.md, deferred_proofs.json to pre-PR022 versions
- Revert DEVLOG.md and BUILD_ROUTE_V2.4.md entries
- One PR, CI green, QA approve, merge