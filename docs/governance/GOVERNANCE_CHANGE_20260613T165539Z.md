# Governance Change -- 10.14B8A -- Dispo Dashboard Packet + Media Approval Read Extension

Date: 20260613T165539Z
Build Route Item: 10.14B8A
Branch: feature/10.14B8A-dispo-dashboard-packet-media-read-extension

## What changed
Extended list_dispo_dashboard_deals_v1 to return 8 dispo_* packet editor fields and derived dispo_below_market_value on each deal item. Extended list_deal_media_v1 to return is_dispo_approved, dispo_approved_at, dispo_approved_by on each media item, and added require_min_role_v1('member') guard. No schema changes. No new RPCs. No privilege changes. No public surface changes.

## Why safe
Both RPCs are SECURITY DEFINER authenticated-only with existing role guards and tenant scope. B8A only adds fields to existing governed read paths. The member role guard added to list_deal_media_v1 tightens the existing access pattern -- it does not loosen it. Public buyer-facing output remains isolated to lookup_share_token_public_v1 which is not touched. No new anon-callable surface introduced.

## Risk
Low. CREATE OR REPLACE on two existing authenticated RPCs. No schema changes. No privilege changes. Existing B7B, B8, and dashboard test suites remain passing (99 files, 1299 tests, PASS).

## Rollback
Revert the PR. Prior RPC bodies restored via db reset. No data loss. No schema rollback required.
