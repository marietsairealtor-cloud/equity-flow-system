# GOVERNANCE CHANGE — 10.11A1 Acquisition Backend Notes/Log Write Path and Activity Log Read Path
UTC: 20260420T011805Z
PR Branch: main
PR HEAD SHA: 3ade7dcd25d9226df1559192ec942c04010e153c

## Change Summary
Backend support for user-authored deal notes/call logs and system activity log
read path. Extends 10.11A backend with missing write and read surfaces required
by 10.11B wiring.

## Items Added
- deal_notes table: tenant-scoped, deal-scoped, stores user notes and call logs
- create_deal_note_v1(p_deal_id, p_note_type, p_content): writes note or call log
- list_deal_notes_v1(p_deal_id): reads notes/call logs for a deal
- list_deal_activity_v1(p_deal_id): reads system activity log for a deal

## Rationale
10.11B wiring review identified two backend gaps:
1. No user-authored note/call log write or read path existed
2. No activity log read RPC existed (foundation_log_activity_v1 is write-only)
These gaps block 10.11B DoD items for Notes/Log and Activity Log sections.

## Why safe
New table and new RPCs only. No changes to existing migrations, RPCs, or tests.
All RPCs follow existing SECURITY DEFINER + tenant isolation pattern.
No WeWeb changes in this item.

## Risk
Low. Additive only. No existing behavior affected.

## Rollback
Revert this PR. No downstream dependencies until 10.11B wires to these RPCs.