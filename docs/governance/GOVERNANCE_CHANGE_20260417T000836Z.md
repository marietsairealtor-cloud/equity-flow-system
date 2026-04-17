# GOVERNANCE CHANGE — 10.8.12A Trial Eligibility UI Surface Correction
UTC: 20260417T000836Z

## What changed
- Migration 20260416000001_10_8_12A_trial_eligibility_ui_surface.sql applied
- get_profile_settings_v1() extended to return has_used_trial boolean
  Sourced from public.user_profiles.has_used_trial
  No signature change. No new RPC. Additive return field only.
  DROP + CREATE used due to return type registration conflict
  GRANT EXECUTE TO authenticated re-applied
- supabase/tests/10_8_11D_profile_settings.test.sql updated:
  plan bumped from 6 to 8
  Two new assertions: has_used_trial field present, has_used_trial=false for seeded user
  Self-contained seed added for deterministic test
- supabase/config.toml: create-checkout-session and stripe-webhook blocks added
  verify_jwt = false for both (required for ES256 token compatibility)
- WeWeb onboarding Step 3 button text updated:
  has_used_trial=false → Create workspace and start 30-day free trial
  has_used_trial=true → Create workspace and subscribe
  Reads from profileSettings variable only -- no frontend trial logic
- Slug input validation added to onboarding button workflow:
  pass-through condition checks input value is non-null and non-empty
  prevents workspace creation with missing slug
- CONTRACTS.md section 40 updated: has_used_trial documented as additive field
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
- Additive return field only -- no signature change
- No new RPC. No new WeWeb globals.
- No frontend trial enforcement -- UI reads backend state only
- Button text is informational only -- enforcement remains in claim_trial_v1()
- config.toml additions fix webhook 401 errors (verify_jwt was blocking Stripe)

## Risk
Low. Additive RPC extension plus config fixes.
config.toml verify_jwt = false is required for both functions to work correctly.

## Rollback
Revert this PR. Run supabase db push to restore previous function definition.
Redeploy Edge Functions if needed.