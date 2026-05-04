# GOVERNANCE CHANGE — 10.12B Intake Forms — Public UI + Submit Wiring
UTC: 20260504T011841Z

## What changed
- New WeWeb page: Public Form at /form/{{slug}}/{{type}}
- Three public intake forms: seller, buyer, birddog
- All forms submit through submit_form_v1(p_slug, p_form_type, p_payload)
- No new RPCs. No new migrations. No schema changes.
- Seller payload: address, name, phone, email, spam_token
- Buyer payload: name, email, phone, areas_of_interest, budget_range, spam_token
- Birddog payload: address, name, phone, email, condition_notes, asking_price, spam_token
- Page states: idle, validation_error, error, invalid_route, success
- formState variable (b33bc3a6-01ab-4da5-93b6-70d198e78880) drives all visibility
- isSubmitting variable controls submit button disabled state
- Workflows registered: public-form-page-load, submit-seller-form, submit-buyer-form, submit-birddog-form
- CONTRACTS.md §65 added
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered
- docs/ui-workflows/WORKFLOWS.md updated with 4 workflows and 2 variables

## Why safe
- No backend changes. submit_form_v1 already existed and is unchanged.
- UI is purely additive. No existing pages modified.
- No direct table calls from WeWeb canvas.
- Slug resolved from URL only, never stored client-side.

## Risk
Low. UI-only item. Backend persistence already proven in 10.12A.

## Rollback
Revert PR. WeWeb page remains but is unpublished.