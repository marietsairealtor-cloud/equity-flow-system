# Governance Change — PR031

## Trigger
Advisor review 2026-02-23 — CI execution surface, IPv4 provisioning, schema-drift dependency resolution, pgtap vacuous pass.

## What changed
- `docs/artifacts/BUILD_ROUTE_V2.4.md` — four new/hardened items per advisor findings:
  - Item 4.6: Two-Tier CI Execution Contract
  - Item 5.2: Direct IPv4 Provisioning
  - Item 5.3: Static Migration-Schema Coupling
  - Item 6.3 DoD hardened: database-tests.yml creation + deferred_proofs.json trigger update
- `docs/DEVLOG.md` — advisor review findings entry

## Decisions declared
1. Two-Tier CI Execution Contract: Tier 1 (pooler/stateless) bans SET, SET LOCAL, temp tables, advisory locks, prepared statements. Existing gates 4.4 and 4.5 grandfathered as Tier 1.
2. IPv4 provisioning before Section 6 — direct host captured in toolchain.json (Item 5.2)
3. schema-drift circular dependency resolved via static coupling gate (5.3) + local ephemeral replay — Section 8 not pulled forward
4. pgtap locked until 6.3/6.4 merged — 6.3 must create database-tests.yml atomically + update deferred_proofs.json triggers to 6.3

## Authority
Three-advisor review 2026-02-23. Decisions grounded against Build Route v2.4, CONTRACTS.md, AUTOMATION.md.

## Why safe
- Documentation and decisions only — no implementation changes
- No scripts, migrations, schema, or CI enforcement surface touched

## Risk
- Low. Build Route amendments add new items and harden existing DoDs. No existing gate modified.