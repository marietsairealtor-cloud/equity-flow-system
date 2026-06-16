# Governance Change -- 10.14B8B -- Dispo Backend -- Expanded Share Packet Fields

Date: 20260616T194217Z
Build Route Item: 10.14B8B
Branch: feature/10.14B8B-expanded-share-packet-fields

## What changed
Added 7 new nullable columns to public.deals: dispo_headline, dispo_tagline, dispo_offer_deadline, dispo_walkthrough, dispo_features, dispo_contact_name, dispo_contact_phone. Extended update_dispo_packet_v1 to accept and save the new fields. Extended list_dispo_dashboard_deals_v1 and lookup_share_token_public_v1 to return the new fields. No new RPCs. No privilege changes. No schema changes beyond the 7 new columns.

## Why safe
All new fields are nullable with NULL defaults -- existing rows unaffected. The save path reuses the existing governed update_dispo_packet_v1 with its existing role guard, tenant scope, workspace write-lock, and stage check. The internal read path reuses list_dispo_dashboard_deals_v1 with existing member guard. The public read path reuses lookup_share_token_public_v1 -- all B7B/B8 invariants preserved: strict token format, bytea hash, NOT_FOUND envelope, no exact address, no seller/internal fields, approved media only. dispo_contact_name and dispo_contact_phone are public deal contact fields, NOT seller contact fields. Rich text safety (dispo_features, dispo_comparables) is enforced at the UI layer in B9 -- documented in B9 proof.

## Risk
Low. Additive schema change only. No existing columns modified. No RPC signatures changed. No privilege changes. Existing B7B/B8/B8A test suites remain passing (100 files, 1342 tests, PASS).

## Rollback
Revert the PR. Prior RPC bodies restored via db reset. New columns can be dropped via forward corrective migration if needed. No data loss from new fields as they default NULL.
