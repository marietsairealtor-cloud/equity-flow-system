# GOVERNANCE CHANGE -- Build Route Addition: 10.14B4A and 10.14B4B
UTC: 20260518T004202Z

## What changed
Two new Build Route items inserted after 10.14B4:

### 10.14B4A -- ACQ UI -- Health Dot Legend
Gate: lane-only
Prerequisite: 10.14B4 merged
Deliverable: Visible ACQ UI legend or tooltip explaining deal health dot colors.
- green / yellow / red meanings documented in UI
- Based on existing get_deal_health_color() backend logic
- Threshold wording follows docs/truth/deal_health_thresholds.json
- No backend change. No migration. No RPC change. No direct table calls.

### 10.14B4B -- ACQ Backend Cleanup -- Remove Orphaned next_action Fields
Gate: merge-blocking
Prerequisite: 10.14B4 merged
Deliverable: Clean up orphaned next_action and next_action_due from deals table,
update_deal_property_v1, and get_acq_deal_v1 after reminder system became
the authoritative follow-up path.
- WeWeb binding audit required before schema removal
- update_deal_property_v1 no longer accepts next_action / next_action_due
- get_acq_deal_v1 no longer returns next_action / next_action_due
- Column removal or deprecation strategy documented after binding audit
- CONTRACTS.md updated
- list_reminders_v1 and reminder system unchanged

## Why
10.14B4A: health dot meaning is not self-evident to operators. No legend exists.
10.14B4B: next_action / next_action_due are orphaned columns -- nothing in the
governed workflow writes to them since the UI moved to the reminder system.
Leaving them in RPCs creates a false contract surface.

## Risk
10.14B4A: zero -- UI only, no backend.
10.14B4B: medium -- RPC output contract change. WeWeb binding audit is a hard
prerequisite before any schema or RPC change is made.

## Authority
Build Route v2.4 -- items inserted by Marie as product owner.
No existing items modified. No gates changed.