# GOVERNANCE CHANGE — 10.11B Acquisition Wiring
UTC: 20260501T004103Z

## What changed
- ACQ page fully wired to governed backend only
- No mock KPI, deal list, or deal detail values remain
- All write paths use governed RPCs only
- No direct table calls from UI

## Wired sections
- KPI strip + date range filter (last7/last30/custom)
- Stage filters + farm area filters
- Deal list + selection
- Deal detail: address, stage, health color
- Copy deal summary
- Send to Dispo (under_contract only)
- Contact actions: Call, Email
- Edit Seller -> update_deal_seller_v1
- Edit Property -> update_deal_property_v1 + update_deal_properties_v1
- Pricing edit -> update_deal_pricing_v1 (mao derived server-side)
- Notes/Log -> create_deal_note_v1 + list_deal_notes_v1
- Next Actions -> create_reminder_v1 + complete_reminder_v1 + list_reminders_v1
- Activity log -> list_deal_activity_v1 (requires 10.11A10)
- Stage CTAs -> advance_deal_stage_v1
- Mark Dead -> mark_deal_dead_v1
- Media -> Supabase storage + register_deal_media_v1 + delete_deal_media_v1

## Media upload pattern
Multi-file upload resolved via WeWeb while-loop pattern:
- File upload element (multiple files, expose as binary ON)
- While loop with uploadIndex variable increments array index
- Each iteration reads live from component variable (binary not storable in WeWeb variables)
- No JavaScript in WeWeb workflows
- Edge function approach (10.11A11) superseded and removed

## 10.11A11 status
Superseded -- not merged, not governed
Edge function removed from repo
Multi-file upload resolved via while-loop pattern

## Prerequisites merged
10.11, 10.11A1, 10.11A2, 10.11A3, 10.11A4, 10.11A5, 10.11A6,
10.11A7, 10.11A8, 10.11A9, 10.11A10 -- all merged

## Risk
Lane-only gate. No backend changes. UI wiring only.
All data access via governed RPC interfaces only.