# GOVERNANCE CHANGE -- 10.14B5A + 10.14B6 Build Route Revision -- Generic Document Vault
UTC: 20260521T231051Z

## What changed
- Build Route 10.14B5 revised: APS-only document backend replaced by generic document vault
- Build Route 10.14B5A added: backend revision item -- allow general document type, remove APS hard gate, add soft-delete remove RPC
- Build Route 10.14B6 revised: APS-specific upload UI replaced by generic Documents section with upload/list/remove
- docs/artifacts/WEWEB_ARCHITECTURE.md updated: Signed APS upload section replaced with Document vault section
- handoff_to_dispo_v1 hard APS gate removed by design -- reminder copy replaces gate in Send to Dispo modal

## Why
APS-only upload is too narrow. Documents are a shared deal vault used by ACQ, Dispo, and TC.
Hard gates create friction when reality is messy -- QA ruling 2026-05-21.
Reminder copy in Send to Dispo modal is the governed replacement for the hard gate.

## QA ruling
QA approved revised design 2026-05-21.
Generic document vault is cleaner than a one-purpose APS checkbox machine.

## Risk
Low. Revision is pre-implementation -- 10.14B5A and revised 10.14B6 not yet built.
10.14B5 is merged but its APS gate will be revised in 10.14B5A migration.