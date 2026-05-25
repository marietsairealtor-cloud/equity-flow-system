# GOVERNANCE CHANGE -- 10.14B7 Dispo Backend -- Buyer-Facing Packet Fields
UTC: 20260525T164913Z

## What changed
- Migration: 20260525000001_10_14B7_dispo_buyer_packet_fields.sql applied
- deals table extended with 8 dispo packet columns:
  - dispo_asking_price numeric NULL
  - dispo_intersection text NULL
  - dispo_closing_date date NULL
  - dispo_description text NULL
  - dispo_comparables text NULL
  - dispo_media_url text NULL (validated: https:// with real host required)
  - dispo_market_value_estimate numeric NULL
  - dispo_below_market_override numeric NULL
- New RPC: update_dispo_packet_v1(p_deal_id uuid, p_fields jsonb)
  - VOLATILE SECURITY DEFINER, authenticated only, min role: member
  - Tenant-scoped, workspace write-lock enforced
  - p_fields jsonb patch semantics: omit=unchanged, explicit null=clear, empty string=normalize to NULL
  - Unknown keys return VALIDATION_ERROR
  - Numeric/date/URL validation is envelope-safe (no raw cast errors)
  - dispo_media_url must be https:// with valid host or empty/null
  - Stage guard: dispo and under_contract only; other stages return CONFLICT
  - Writes deal_activity_log on mutation
- New RPC: lookup_share_token_public_v1(p_token text)
  - STABLE SECURITY DEFINER
  - GRANT EXECUTE to anon AND authenticated
  - No current_tenant_id() required -- token-first resolution
  - Validates format, hashes token, resolves tenant/deal from share_tokens row
  - Checks revoked, expired, workspace subscription after token resolution
  - Returns only allowlisted buyer-facing packet fields (no exact address, no seller/internal fields)
  - Identical NOT_FOUND envelope across all failure cases (no existence leak)
- lookup_share_token_v1 unchanged -- authenticated tenant-scoped contract preserved
- Share token lookup is now split by caller class per QA ruling 2026-05-25:
  - lookup_share_token_v1: authenticated, tenant-scoped internal lookup
  - lookup_share_token_public_v1: public buyer-facing lookup, token is authorization

## Why safe
Additive schema change only -- 8 nullable columns added to deals.
update_dispo_packet_v1 is authenticated-only with full guard stack.
lookup_share_token_public_v1 is read-only STABLE, returns allowlisted fields only.
lookup_share_token_v1 is unchanged -- no regression to existing authenticated share token contracts.
All RPCs remain SECURITY DEFINER with fixed search_path.

## Risk
Low. Additive. No existing RPC modified except lookup_share_token_v1 which is unchanged.
New anon-callable RPC is read-only and returns only buyer-facing packet fields.

## Rollback
Revert PR. Nullable columns can remain (no impact). lookup_share_token_public_v1 can be dropped.