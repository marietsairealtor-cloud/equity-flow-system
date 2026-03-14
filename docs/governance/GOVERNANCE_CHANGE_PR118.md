# Governance Change — PR118

## What changed

Build Route v2.4 amended to add item 10.7.1 — Legacy Gate Promotion
Retrofit. Added immediately following item 10.7 in
docs/artifacts/BUILD_ROUTE_V2.4.md. Three historical lane-only gates
with explicit promotion triggers are backfilled into
docs/truth/gate_promotion_registry.json:

- command-smoke-db (Build Route 4.2a) — trigger: promote to
  merge-blocking only after stable
- surface-truth (Build Route 9.1) — trigger: lane-only until stable
- ci_validator (Build Route 2.17.4) — trigger: promote only if it
  catches real corruption

Each entry sets status to lane-only and promoted_by to null.

## Why this is needed

Item 10.7 established gate_promotion_registry.json with scope limited
to Section 10 per QA ruling. Post-merge QA review identified three
historical lane-only gates from earlier sections that possess explicit
promotion triggers — making them promotable gates that belong under
mechanical enforcement. These gates were excluded from 10.7 initial
population per the original scope ruling, but their explicit triggers
mean they require formal registration to prevent uncontrolled promotion.
Item 10.7.1 governs this backfill as a discrete, traceable PR.

## Why safe

This PR modifies three files only:
- docs/artifacts/BUILD_ROUTE_V2.4.md: Build Route specification update
- docs/truth/gate_promotion_registry.json: adds 3 new lane-only entries
- docs/governance/GOVERNANCE_CHANGE_PR118.md: this file

No migrations, no schema changes, no RPC signature changes, no CI
topology changes, no required.needs changes. The gate-promotion-registry
CI job will continue to pass — new entries are lane-only with
promoted_by null, which satisfies the verifier rules.

## Risk

Low. Registry entries are additive. Three new lane-only entries with
null promoted_by. Verifier rules for lane-only gates: must not be in
required_checks.json or required.needs — all three satisfy this.
No existing gates affected.

## Rollback

Remove the three new entries from gate_promotion_registry.json and
revert BUILD_ROUTE_V2.4.md via follow-on PR with governance file.
No migrations or schema changes to undo.