# GOVERNANCE CHANGE — Build Route v2.4 Addition — 10.8.11K and 10.8.11L
UTC: 20260406T191034Z

## What changed
Added Build Route items 10.8.11K (Subscription Status Consistency) and 10.8.11L
(Renew Now Routing Fix) to BUILD_ROUTE_V2_4.md. Both are bridge fixes identified
during 10.8.11I authoring. 10.8.11K corrects resolveStatus mapping in stripe-webhook
Edge Function and documents two-tier status model. 10.8.11L fixes Renew Now CTA
routing away from onboarding to billing entry point. Both are lane-only gates.
Additive only. No existing items modified.

## Why safe
Build Route additions are planning documents only. No schema changes in this PR.
No RPC changes in this PR. No gate logic changed. Both items are lane-only —
no merge-blocking impact. Individual item PRs will carry migrations, tests, and
proofs as required. stripe-webhook fix is an Edge Function change only, no
Postgres migration needed.

## Risk
Low. Additive documentation only. No executable code changed. No migrations.
No existing CI gates affected. Both new items are lane-only gates only.

## Rollback
Revert this PR. No database state to undo. No generated artifacts affected.
Re-run npm run handoff to confirm zero diffs after revert.