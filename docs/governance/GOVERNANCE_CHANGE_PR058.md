# Governance Change PR058 — 6.10 Activity Log Append-Only

## What changed
Added append-only enforcement to `public.activity_log` via a BEFORE trigger on UPDATE and DELETE. Added REVOKE of UPDATE and DELETE privileges on `activity_log` from `authenticated`. Added pgTAP tests proving INSERT succeeds and UPDATE/DELETE are blocked.

## Why safe
The trigger raises a deterministic exception on any mutation attempt. No existing product code performs UPDATE or DELETE on `activity_log`. The REVOKE aligns with the existing schema which already had no UPDATE/DELETE policies. This hardens an invariant that was already implied by policy but not enforced at DB physics level.

## Risk
Low. The trigger blocks mutations unconditionally. Any future legitimate mutation path would require a new migration to drop the trigger, which would be caught by governance review.

## Rollback
Drop triggers `activity_log_no_update` and `activity_log_no_delete`, drop function `public.activity_log_append_only()`, and re-grant UPDATE/DELETE to `authenticated` if required. All reversible via a single migration PR.
