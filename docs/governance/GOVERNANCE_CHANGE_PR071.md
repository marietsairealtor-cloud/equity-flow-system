# Governance Change PR071 — 7.7 Supabase Studio Direct-Mutation Guard

## What changed
Added operator mutation policy docs/ops/STUDIO_MUTATION_POLICY.md declaring
that all schema changes must go through migrations. Added operator-run drift
detection script scripts/cloud_schema_drift_check.ps1. Registered
STUDIO_MUTATION_POLICY.md in governance-change-guard path scope and
governance_surface_definition.json so future policy changes trigger the
governance-change-guard. No CI gate added — this is operator-run only.

## Why safe
Purely additive. No migrations, schema, RPC, or CI behavior changes. The
drift check script requires manual operator invocation with explicit cloud
credentials — it cannot run in CI and cannot expose secrets in logs.

## Risk
None. Documentation and tooling addition only. No behavioral change to any
production code path.

## Rollback
Delete docs/ops/STUDIO_MUTATION_POLICY.md and scripts/cloud_schema_drift_check.ps1,
remove path entries from governance_change_guard.json and
governance_surface_definition.json via a single governance PR.
