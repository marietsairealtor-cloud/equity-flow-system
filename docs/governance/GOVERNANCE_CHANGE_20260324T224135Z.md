# GOVERNANCE_CHANGE_20260324_224135Z

## What changed
Redesigned invite acceptance from token-carry-through after auth to post-auth pending invite resolution via 'accept_pending_invites_v1(). Updated docs/WEWEB_ARCHITECTURE.md (Section 5.1 Auth Page, 5.2 Onboarding, 5.3 Gate Logic), docs/CONTRACTS.md (added Section 34 Pending Invite Resolution RPC 10.8.7E), and docs/build_route.md (added 10.8.7E and 10.8.7F, revised 10.8.7B deliverable wording, replaced 10.8.8, replaced 10.8.9, updated 10.8.11). Added governance file for this redesign.

## Why safe
This change removes the brittle auth-redirect token handoff without weakening the business model. Authorization remains based on authenticated control of the invited email, backend RPCs remain the source of truth, entitlement-driven routing is unchanged, and no direct table calls or frontend-supplied email parameters are introduced.

## Risk
Primary risk is documentation drift between WEWEB_ARCHITECTURE, CONTRACTS, and Build Route if future changes update only part of the system. Secondary risk is overlap or ambiguity between 10.8.7B, 10.8.7E, 10.8.7F, and 10.8.8 if implementation does not follow the updated contracts exactly.

## Rollback
Revert this governance change in a dedicated governance PR and restore prior token-carry-through wording in WEWEB_ARCHITECTURE, CONTRACTS, and Build Route. No runtime schema or data changes are performed by this governance file, so rollback is documentation-only at this stage.
