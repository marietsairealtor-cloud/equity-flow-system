# Governance Change — PR016

## What changed
- `docs/truth/deferred_proofs.json` — new hand-authored registry of DB-heavy stub gates
- `docs/truth/deferred_proofs.schema.json` — schema validating registry structure
- `scripts/ci_deferred_proof_registry.ps1` — new gate asserting registry completeness
- `.github/workflows/ci.yml` — added deferred-proof-registry job, wired into required:
- `docs/truth/required_checks.json` — added CI / deferred-proof-registry
- `docs/truth/qa_claim.json` — updated to 3.9.1
- `docs/truth/qa_scope_map.json` — added 3.9.1 entry

## Why safe
- Registry is additive — catalogs existing stub gates, changes no enforcement surface
- Gate fails only if a stub gate has no registry entry or a converted gate still has one
- No schema, migration, or security surface touched
- §3.0.4c exemption documented in Build Route for deferred_proofs.json and schema

## Risk
- Low. New merge-blocking gate adds visibility into stub debt. Cannot cause false positives
  on existing gates — only checks registry completeness against CI YAML echo-pattern stubs.

## Rollback
- Remove scripts/ci_deferred_proof_registry.ps1
- Remove docs/truth/deferred_proofs.json and deferred_proofs.schema.json
- Remove deferred-proof-registry job from ci.yml and required: needs
- Remove CI / deferred-proof-registry from required_checks.json
- One PR, CI green, QA approve, merge