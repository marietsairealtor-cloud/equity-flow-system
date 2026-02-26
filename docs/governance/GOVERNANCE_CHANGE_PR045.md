# GOVERNANCE_CHANGE_PR045

## What changed
Build Route 6.4 DoD block completed to restore missing structural audit requirements from prior version. Added explicit DoD bullets covering selector truth assertion, pgTAP rejection of permissive RLS patterns, full policy enumeration requirement, and explicit Proof + Gate declarations (pgtap merge-blocking).

## Why safe
Docs-only correction. No new gate introduced. No enforcement logic altered. Restores previously intended DoD text to ensure completeness and audit clarity. Does not expand scope beyond existing 6.4 RLS structural audit contract.

## Risk
Low. Documentation alignment only. No schema change, no CI modification, no truth file mutation, no gate behavior change.

## Rollback
Revert docs/artifacts/BUILD_ROUTE_V2.4.md to prior revision and remove GOVERNANCE_CHANGE_PR045.md.