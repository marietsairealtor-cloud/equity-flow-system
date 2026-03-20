## What changed
Added Supabase Storage bucket tc-contracts via migration 20260319000008. Storage RLS policies enforce exact path contract {tenant_id}/{deal_id}/contract.pdf with full 3-segment validation. PDF only, 10MB limit, no anon access. Updated CONTRACTS.md s30 with bucket documentation. Updated ci_robot_owned_guard.ps1 with 10.8.7 proof log pattern.

## Why safe
Additive only. New storage bucket and RLS policies. No existing RPCs, tables, or enforcement rules modified. Storage RLS uses current_tenant_id() per CONTRACTS s28 authorized exception.

## Risk
Low. New storage surface only. RLS strictly enforces path shape and tenant isolation. No direct table grants added.

## Rollback
Revert PR implementing 10.8.7. Drop tc-contracts bucket via compensating migration. Remove Storage RLS policies.