# GOVERNANCE CHANGE — 10.11 Acquisition Dashboard UI
UTC: 20260419T171139Z
PR Branch: feature/10.11-acquisition-dashboard-ui
PR HEAD SHA: 1f8ea2cb8fce6832181b368ce817c12f8fc7d9f0

## Change Summary
WeWeb UI shell for Acquisition Dashboard — 10.11.
No migrations. No RPCs. No schema changes. UI only.

## What changed
- Acquisition page built in WeWeb at /acquisition
- KPI strip: Contracts Signed, Lead-to-Contract %, Avg Projected Assignment Fee
- Acq queue filters: All, New, Analyzing, Offer Sent, Follow-ups, UC
- Deal list with health dot, address, pricing, next-action, stage chip, owner
- Deal detail: header, next action + quick contact, seller motivation, property
  condition, pricing snapshot, notes/log, follow-up reminders, activity log
- Stage-gated CTAs per stage (no generic dropdown)
- Mark dead universal for all active non-terminal stages
- Send to Dispo modal triggered from header (UC stage only)
- Edit buttons on seller motivation and property condition open popups
- Activity log renders mock entries only — live wiring deferred to 10.11B
- No Zillow/Redfin/Realtor.com links
- No close angle block
- No objection/blocker block
- No Return to Acq button
- No direct table calls

## Why safe
WeWeb-only. No backend changes. No migrations. No RPC changes.
All data placeholders/mock only in this item. Lane-only gate.

## Risk
Low. Frontend shell only. No backend state affected.

## Rollback
Revert this PR. No database state to undo.