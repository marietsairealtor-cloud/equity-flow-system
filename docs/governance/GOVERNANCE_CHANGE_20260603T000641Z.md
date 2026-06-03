# Governance Change — 10.14B7B Dispo Packet RPC Landing Repair

## What changed
Added four forward corrective migrations splitting the 10.14B7 dispo packet RPCs into standalone single-statement files: 20260526000001 (update_dispo_packet_v1 RPC), 20260526000002 (update_dispo_packet_v1 grants), 20260526000003 (lookup_share_token_public_v1 RPC), 20260526000004 (lookup_share_token_public_v1 grants). Updated 10_14B7_dispo_buyer_packet_fields.test.sql with explicit uuid casts and JWT claim GUCs.

## Why safe
The B7 and B7A migrations are not rewritten. The four B7B migrations are forward-only correctives that recreate the same RPCs with identical bodies and grant posture. No schema change, no new tables, no new columns, no privilege escalation. Splitting into single-statement migrations makes failure loud and diagnosable instead of silent. The test fix corrects pgTAP authoring errors only.

## Risk
Low. Function bodies are identical to approved B7 contract. Grant posture unchanged. No behavioral change to any RPC. Split migrations remove ghost-state ambiguity from the migration runner.

## Rollback
Revert the four B7B migration files via a forward migration that drops and recreates the functions from B7A if needed. Original B7 and B7A remain in place.