# Governance Change -- 10.14B8 -- Dispo Share Packet Photo Visibility

Date: 20260609T010629Z
Build Route Item: 10.14B8
Branch: feature/10.14B8-dispo-share-packet-photo-visibility

## What changed
Added is_dispo_approved, dispo_approved_at, dispo_approved_by columns to public.deal_media. New governed RPC update_deal_media_dispo_approval_v1 controls opt-in approval for the public buyer-facing dispo share packet. lookup_share_token_public_v1 extended to return approved media under data.media, filtered by tenant_id + deal_id + is_dispo_approved.

## Why safe
Media exposure is opt-in. All existing media defaults to is_dispo_approved = false -- nothing is newly exposed. The mutation RPC is authenticated-only, member-role-gated, and workspace-write-locked. The public lookup filters media by both tenant_id and deal_id explicitly -- no reliance on FK constraints alone. All B7B token validation, hash logic, and NOT_FOUND envelope invariants are preserved unchanged.

## Risk
Low. Schema change is additive and backward compatible. Default false means no existing media is exposed without explicit operator action. New RPC follows the same guard pattern as approved B7B RPCs. pgTAP suite passes 1278 tests including 42 new B8-specific assertions.

## Rollback
Revert the PR. The three B8 migrations can be reversed by dropping the three deal_media columns and dropping update_deal_media_dispo_approval_v1. lookup_share_token_public_v1 can be restored to the B7B body via a forward corrective migration. No data loss -- the approval columns contain no business-critical data that does not exist elsewhere.
