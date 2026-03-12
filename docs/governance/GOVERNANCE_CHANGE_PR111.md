# Governance Change — PR111

## What changed

Build Route v2.4 appended with eleven new items: 10.13 (Gate Promotion
Protocol) and 10.14–10.23 (WeWeb UI Build block). Item 10.13 establishes
gate_promotion_registry.json as a new truth file and a merge-blocking gate
(gate-promotion-registry) governing the mechanical path for promoting any
lane-only gate to merge-blocking. Items 10.14–10.23 define the governed
build sequence for all WeWeb UI surfaces: public free MAO calculator,
Command Centre dashboards (Acquisition, Offer Generator, Dispo, TC),
Buyer-Ready Deal Packet share link surface, four intake forms, and
end-to-end wiring verification. All 10.14–10.23 gates are lane-only until
promoted. Design decisions covering Command Centre structure, stage-to-view
mapping, valid stage transitions, free tier statelessness, and upgrade path
are locked as authoritative for this block.

## Why safe

All additions are Build Route documentation only. No migrations, no schema
changes, no RPC signature changes, no Foundation paths touched. Existing
merge-blocking gates are not modified or removed. The one new merge-blocking
gate introduced (gate-promotion-registry, item 10.13) governs a new truth
file and does not interact with existing DB or contract surfaces. Items
10.14–10.23 are lane-only — they cannot block merge until explicitly
promoted via the 10.13 protocol. Foundation Boundary contract (2.16.5A) is
not implicated. All RPCs referenced in 10.14–10.23 are existing allowlisted
RPCs already governed by CONTRACTS.md.

## Risk

Low. Pure documentation addition. No executable code introduced in this PR.
The only mechanical change is item 10.13 which adds one new merge-blocking
gate and one new truth file. If gate-promotion-registry is misconfigured,
CI will catch it before merge. Lane-only gates (10.14–10.23) carry no merge
risk until promotion. Design decisions locked in this PR constrain future
UI build items — if decisions prove wrong during implementation, a follow-on
governance PR is required to amend them, which is the correct control path.

## Rollback

Revert the Build Route addition commit. No truth files, migrations, or
schema changes to undo for items 10.14–10.23. For item 10.13: remove
gate_promotion_registry.json, remove gate-promotion-registry from ci.yml
and required_checks.json, run truth:sync, open revert PR with governance
file. All lane-only gates revert to undocumented promotion path (same state
as before this PR).