# GOVERNANCE CHANGE -- 10.14B7A Corrective Migration -- Dispo Packet RPC Search Path Fix
UTC: 20260525T233511Z

## What changed
- Migration: 20260525000002_10_14B7A_dispo_packet_rpc_search_path_fix.sql added
- Recreates update_dispo_packet_v1(uuid,jsonb) with SET search_path = public
- Recreates lookup_share_token_public_v1(text) with SET search_path = public
- Original 10.14B7 migration not modified
- Function bodies and grants unchanged from approved 10.14B7 logic
- BUILD_ROUTE_V2.4.md updated with 10.14B7A item

## Root cause
10.14B7 original migration used SET search_path TO 'public' (quoted string with TO keyword)
on lookup_share_token_public_v1. This non-standard syntax caused silent failure during
supabase db reset -- migration recorded as applied but functions absent from pg_proc.
Both RPCs affected: update_dispo_packet_v1 and lookup_share_token_public_v1.

## Why safe
Forward corrective only. No schema changes. No new tables. No privilege changes.
Grants preserved: update_dispo_packet_v1 to authenticated; lookup_share_token_public_v1 to anon + authenticated.
Function bodies identical to approved 10.14B7 logic.
After fix: both functions land in pg_proc after db reset.

## Risk
Low. CREATE OR REPLACE on existing functions. No data migration.

## Rollback
Revert PR. Functions revert to broken search_path variant from 10.14B7.