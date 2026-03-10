# Governance Change PR101 - 9.1 Surface Truth Schema + Canonicalization

## What changed
Added surface truth schema, canonicalization harness, and CI gate.
- docs/truth/surface_truth.schema.json: expanded from stub to full schema
  with required fields: version, captured_at, rpc, tables, anon_exposed.
- docs/truth/surface_truth.json: first authoritative capture of PostgREST
  surface. RPCs: create_deal_v1, current_tenant_id, get_user_entitlements_v1,
  list_deals_v1, update_deal_v1. Tables: none (privilege firewall enforced).
- scripts/capture_surface_truth.mjs: harness that queries PostgREST OpenAPI
  and writes canonicalized surface_truth.json deterministically.
- scripts/ci_surface_truth.mjs: CI gate that compares live surface against
  truth file. Fails on any addition or removal.
- docs/truth/lane_policy.json: added surface-truth lane.
- package.json: added surface:capture and surface:verify scripts.

## Why safe
Additive only. No schema changes. No RPC changes. Harness is read-only
against PostgREST OpenAPI endpoint. CI gate is informational until wired
into required_checks.

## Risk
Low. surface_truth.json must be updated whenever an RPC is added to the
PostgREST surface. Failure to update will cause ci_surface_truth gate to
fail.

## Rollback
Remove surface_truth.json, capture_surface_truth.mjs, ci_surface_truth.mjs,
and revert lane_policy.json.
