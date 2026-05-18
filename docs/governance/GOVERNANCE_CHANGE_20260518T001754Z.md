# GOVERNANCE CHANGE -- 10.14B4 Lead Intake + ACQ UI -- Electrical/Plumbing Wiring
UTC: 20260518T001754Z

## What changed
- ACQ Edit Property popup: Input-electrical and Input-plumbing fields added
- ACQ Edit Property popup: both fields seeded from selectedDeal.data.properties.electrical/plumbing
- ACQ Edit Property popup: save-property workflow p_fields extended with electrical and plumbing
- Lead Intake Review (/lead-intake/new): electrical and plumbing input fields added
- promote-draft-deal workflow p_fields extended with electrical and plumbing
- create-deal-from-intake workflow p_fields extended with electrical and plumbing
- ACQ deal list card: orphaned next_action display line removed (field moved to reminder system)
- WORKFLOWS.md updated: save-property, promote-draft-deal, create-deal-from-intake
- No backend changes. No migrations. No new RPCs.

## Why safe
Additive UI only. Both backend RPCs (update_deal_properties_v1, get_acq_deal_v1) already
accept and return these fields as of 10.14B3. No contract changes. No schema changes.
Null inputs are handled by the RPC (omitted = no change).
Public seller intake form not touched.

## Risk
Low. UI-only change. No governed backend surface modified.

## Rollback
Revert WeWeb publish. No DB changes to revert.