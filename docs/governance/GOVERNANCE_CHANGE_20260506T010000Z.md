# GOVERNANCE CHANGE — BUILD_ROUTE roadmap add 10.12C3 (Lead Intake submission list filter)

UTC: 20260506T010000Z

## What changed

- `docs/artifacts/BUILD_ROUTE_V2.4.md`: inserted roadmap item 10.12C3 (Intake Backend — Lead Intake Submission List Filter) after 10.12C2, with QA-specified `list_intake_submissions_v1` DoD, tests, proof path `docs/proofs/10.12C3_list_intake_submissions_fix_<UTC>.log`, merge-blocking gate, prerequisite 10.12C2 merged; 10.12D prerequisite updated to include 10.12C3.

## Alignment

Lead Intake scope: seller/birddog review queue only; buyer operational views remain Dispo-aligned per existing `list_buyers_v1` / 10.14C framing.

## Why safe

Adds a numbered Build Route backlog item consistent with QA ruling; runtime change is authored in migration 10.12C3 plus pgTAP and CONTRACTS/registry updates in this repo.

## Risk

Low — backlog documentation and traceability unless implementation omits mandated server-side omission of buyer rows.
