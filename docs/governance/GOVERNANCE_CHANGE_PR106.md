# GOVERNANCE_CHANGE_PR106.md

## What changed

Section 9 hardening and Section 10 contract enforcement amendments per advisor review 2026-03-11. Two security hardening controls added to Section 9 (9.6 PostgREST data surface truth, 9.7 share token maximum lifetime invariant). Three behavioral contract enforcement mechanisms added to Section 10 (10.9 RPC response schema contracts, 10.10 RPC response contract tests, 10.11 RPC error contract tests). Build Route amended to include items 9.6, 9.7, 10.9, 10.10, 10.11. No existing rules weakened. No architectural direction changed.

## Why safe

All changes extend CI enforcement to match existing contract declarations — no new architectural policy is introduced. Section 9 amendments enforce invariants already implied by CONTRACTS SS1, S12, S17, S21. Section 10 additions verify RPC response envelopes and error codes already mandated by CONTRACTS S1. The only runtime behavior change is the 90-day upper bound on share token expires_at (9.7), which is a new stricter validation returning VALIDATION_ERROR — a safe additive constraint. No existing valid tokens are affected. No RLS, privilege, or tenancy logic is altered.

## Risk

Low. Section 9 amendments add CI verification gates only — no migration required for 9.6. Item 9.7 adds a VALIDATION_ERROR path to create_share_token_v1 for tokens with expires_at > 90 days; callers using reasonable expiry windows are unaffected. Section 10 additions are schema contract tests and do not modify any RPC signatures or DB objects. All changes are additive only.

## Rollback

For 9.7: revert the migration that adds the 90-day upper bound check via a new forward migration restoring the prior function body. No data migration required. For 9.6, 10.9, 10.10, 10.11: remove the added CI gate scripts and truth files via a governance PR. No DB state is affected by any Section 10 rollback.