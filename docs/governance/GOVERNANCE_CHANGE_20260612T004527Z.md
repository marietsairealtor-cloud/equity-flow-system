# Governance Change -- 10.14B8A -- Dispo Dashboard Packet + Media Approval Read Extension

Date: 20260612T004527Z
Build Route Item: 10.14B8A
Branch: feature/10.14B8A-dispo-dashboard-packet-media-read-extension

## What changed
10.14B8A extends list_dispo_dashboard_deals_v1 to return the 8 dispo packet editor fields, derived below-market value, and deal media with approval state on each deal item. This is a read-only extension to an existing governed authenticated RPC. No new public behavior. No new anon-callable surface.

## Why safe
The write paths for packet fields and photo approval already exist and are governed: update_dispo_packet_v1 and update_deal_media_dispo_approval_v1. B8A adds only the corresponding operator read path. The existing role guard, tenant scope, and NOT_AUTHORIZED/NOT_FOUND envelopes are preserved. Public buyer-facing output remains isolated to lookup_share_token_public_v1 which is not touched by this item. lookup_share_token_v1 is also not touched. No direct table reads are introduced in the UI.

## Risk
Low. Extension of an existing SECURITY DEFINER authenticated RPC. No new RPCs created. No schema changes. No privilege changes. No public surface changes. The preferred architecture of extending the existing governed read path avoids creating a duplicate packet-only read RPC and reduces surface area.

## Rollback
Revert the PR. The prior list_dispo_dashboard_deals_v1 body is restored via db reset. No data loss. No schema rollback required.
