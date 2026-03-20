## What changed
Added Supabase Storage bucket deal-photos via migration 20260320000001. Storage RLS policies enforce path contract {tenant_id}/{deal_id}/{photo_id} with 3-segment validation and segment[1]=tenant_id via current_tenant_id(). JPEG and PNG only, 10MB limit, no anon access. Updated CONTRACTS.md s31, ci_robot_owned_guard.ps1, qa_claim.json, qa_scope_map.json.

## Why safe
Additive only. New storage bucket and RLS policies following identical pattern to 10.8.7 tc-contracts bucket. No existing RPCs, tables, or enforcement rules modified.

## Risk
Low. New storage surface only. RLS strictly enforces path shape and tenant isolation.

## Rollback
Revert PR. Drop deal-photos bucket via compensating migration. Remove Storage RLS policies.