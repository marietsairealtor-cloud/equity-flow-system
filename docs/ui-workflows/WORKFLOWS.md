# WeWeb Workflow Registry

Single lookup table for all WeWeb workflows.
Search by variable name, RPC, page, or item to find every workflow that touches it.

**Enforcement:** QA rejects any PR where a WeWeb workflow changed but this file was not updated.
No new CI gate. No new proof artifact.

---

## Entry Format

```
## workflow-name
Trigger: page or element that fires this workflow
Reads: variables or globals consumed as input
Calls: RPCs or Edge Functions called, in order
Writes: variables or globals mutated by this workflow
Branches: condition → destination | condition → destination
Item: Build Route item that introduced this workflow
```

---

## Fetch Workflows (data load only, no branches)

## fetch-workspace-list
Trigger: hamburger-switch-workspace on mount, workspace-switcher item on-click
Reads: auth session
Calls: list_user_tenants_v1()
Writes: workspaceList variable
Item: 10.8.11C / 10.8.11I9

---

## fetch-archived-workspaces
Trigger: /onboarding page load, hamburger menu popup mount
Reads: auth session
Calls: list_archived_workspaces_v1()
Writes: archivedWorkspaces variable (43bcf348-3de2-4369-b2d0-08b5c234d754)
Item: 10.8.11O3 / 10.8.11P

---

## fetch-entitlements
Trigger: called by post-auth-routing and other workflows needing entitlement refresh
Reads: auth session, current_tenant_id from user profile
Calls: get_user_entitlements_v1()
Writes: entitlements variable (0237d4bd-5f1b-46d7-9851-19c0aadd695e)
Item: 10.8.8 / 5A

---

## fetch-farm-area-list
Trigger: Workspace Settings Farm Areas tab load, called after add/remove mutations
Reads: auth session, current_tenant_id
Calls: list_farm_areas_v1()
Writes: farmAreas variable
Item: 10.8.11H

---

## fetch-pending-invite-list
Trigger: Workspace Settings Members tab load, called after invite/rescind mutations
Reads: auth session, current_tenant_id
Calls: list_pending_invites_v1()
Writes: pendingInvites variable
Item: 10.8.11I3 / 10.8.11I4

---

## fetch-profile-settings
Trigger: Profile Settings page load, onboarding page load
Reads: auth session
Calls: get_profile_settings_v1()
Writes: profileSettings variable (4c345731-3d2f-4610-b69e-422394b064a0)
Item: 10.8.11D / 10.8.12A

---

## fetch-slug-check-result
Trigger: called by onboarding-button before SLUG CHECK condition
Reads: SLUG input value (9ec992f6-4cb8-402e-865a-38f4113c5112-value)
Calls: check_slug_access_v1(p_slug=SLUG)
Writes: gs_slugCheckResult (60ace435-0c5f-4a74-858f-9d6a4e2a1260)
Item: 10.8.8D

---

## fetch-workspace-members
Trigger: Workspace Settings Members tab load, called after role/remove mutations
Reads: auth session, current_tenant_id
Calls: list_workspace_members_v1()
Writes: workspaceMembers variable
Item: 10.8.11G / 10.8.11I

---

## fetch-workspace-settings
Trigger: Workspace Settings page load, called after save mutations
Reads: auth session, current_tenant_id
Calls: get_workspace_settings_v1()
Writes: workspaceSettings variable (13fb0509-4a8f-4799-a4e8-2f491cd36ef6)
Item: 10.8.11E

---

## Action Workflows

## post-auth-routing
Trigger: /post-auth page load
Reads: auth session
Calls: accept_pending_invites_v1() → get_user_entitlements_v1()
Writes: entitlements variable (0237d4bd-5f1b-46d7-9851-19c0aadd695e)
Branches: is_member=false → /onboarding | app_mode=archived_unreachable → /onboarding | app_mode=normal or read_only_expired → /today
Item: 10.8.8 / 10.8.11M / 10.8.11O2 / 10.8.11P

---

## onboarding-page-load
Trigger: /onboarding page load
Reads: auth session
Calls: get_user_entitlements_v1() → list_archived_workspaces_v1() → get_profile_settings_v1()
Writes: entitlements variable (0237d4bd), archivedWorkspaces variable (43bcf348), profileSettings variable (4c345731)
Branches: none
Item: 10.8.11D / 10.8.11P / 10.8.12A

---

## onboarding-button
Trigger: Create workspace button click on /onboarding Step 3
Reads: slug input value (9ec992f6-4cb8-402e-865a-38f4113c5112-value), SLUG variable (8654687c-8461-49a0-b3a3-f446d02cb55b), gs_pendingIdempotencyKey
Calls: [pass-through: slug non-null/non-empty] → fetch-slug-check-result → check_slug_access_v1(p_slug) → create_tenant_v1(p_idempotency_key) → set_current_tenant_v1(p_tenant_id) → set_tenant_slug_v1(p_slug) → create-checkout-session Edge Function
Writes: gs_slugCheckResult (60ace435), gs_pendingIdempotencyKey (1e0de628), is_loading
Branches: slug empty → stop | slug taken + is_owner_or_admin=true → Stripe redirect | slug taken + not owner → error | slug available → create workspace → Stripe redirect
Item: 10.8.8 / 10.8.9 / 10.8.12 / 10.8.12A

---

## hamburger-switch-workspace
Trigger: Hamburger menu mount / open
Reads: auth session
Calls: list_user_tenants_v1()
Writes: workspaceList variable, showWorkspaceList (set to true)
Branches: none
Item: 10.8.11C / 10.8.11I9

---

## hamburger-archived-workspaces
Trigger: Archived Workspaces item in hamburger dropdown
Reads: archivedWorkspaces variable (43bcf348-3de2-4369-b2d0-08b5c234d754)
Calls: none — navigate only
Writes: none
Visibility condition: variables['43bcf348-3de2-4369-b2d0-08b5c234d754']?.['data']?.['items']?.['length'] > 0
Branches: visible → navigate to /onboarding | items empty → hidden
Item: 10.8.11P

---

## workspace-switcher
Trigger: Switch workspace item click in hamburger dropdown
Reads: selected tenant_id from workspaceList repeater
Calls: set_current_tenant_v1(p_tenant_id) → fetch-entitlements
Writes: entitlements variable (0237d4bd)
Branches: none — switches context and reloads entitlements
Item: 10.8.11B / 10.8.11I9

---

## expired-banner-visibility
Trigger: authenticated shell — evaluated on entitlements load/refresh
Reads: entitlements variable (0237d4bd) — app_mode, subscription_status, subscription_days_remaining, can_manage_billing
Calls: none — display logic only
Writes: none
Visibility condition: variables['0237d4bd-5f1b-46d7-9851-19c0aadd695e']?.data?.app_mode == 'read_only_expired' || variables['0237d4bd-5f1b-46d7-9851-19c0aadd695e']?.data?.subscription_status == 'expiring'
Banner text: app_mode=read_only_expired → 'Subscription expired. This workspace is read-only. Renew within 60 days to avoid data loss.' | expiring → 'Your subscription expires in {subscription_days_remaining} days.'
Manage billing button visibility: variables['0237d4bd-5f1b-46d7-9851-19c0aadd695e']?.data?.can_manage_billing === true
Manage billing button action: window.open('https://billing.stripe.com/p/login/test_00w5kDc8XcC1aNtbcLgbm00', '_blank')
Branches: none — display only
Item: 10.8.11K / 10.8.11L / 10.8.11P

---

## restore-workspace
Trigger: Restore workspace button click in onboarding archived workspaces list
Reads: item.restore_token from archivedWorkspaces repeater
Calls: restore_workspace_v1(p_restore_token) → fetch-entitlements
Writes: entitlements variable
Branches: success → /today | failure → error state
Item: 10.8.11O3 / 10.8.11P

---

## subscribe-to-restore
Trigger: Subscribe to restore workspace button click in onboarding archived workspaces list
Reads: item.restore_token, auth session
Calls: create-restore-checkout-session Edge Function (POST with restore_token)
Writes: none — redirects to Stripe
Branches: success → window.location.href = Stripe URL | failure → error
Item: 10.8.11P

---

## profile-settings-save-display-name
Trigger: Save button on Profile Settings page
Reads: display name input value
Calls: update_display_name_v1(p_display_name) → fetch-profile-settings workflow
Writes: profileSettings variable (4c345731)
Branches: none
Item: 10.8.11J

---

## workspace-settings-save
Trigger: Save changes button on Workspace Settings General tab
Reads: workspace name, slug, country, currency, measurement_unit inputs
Calls: update_workspace_settings_v1() → fetch-workspace-settings workflow → fetch-workspace-list workflow
Writes: workspaceSettings variable (13fb0509), workspaceList variable
Branches: none
Item: 10.8.11F

---

## members-invite
Trigger: Invite button on Workspace Settings Members tab
Reads: email input, role dropdown
Calls: invite_workspace_member_v1(p_email, p_role) → fetch-pending-invite-list workflow
Writes: pendingInvites variable
Branches: none
Item: 10.8.11G / 10.8.11I1 / 10.8.11I3

---

## members-remove
Trigger: Remove button on Members tab member row
Reads: item.user_id from workspaceMembers repeater
Calls: remove_member_v1(p_user_id) → fetch-workspace-members workflow
Writes: workspaceMembers variable
Branches: none
Item: 10.8.11G

---

## members-rescind-invite
Trigger: Cancel invite button on pending invites list
Reads: item.invite_id from pendingInvites repeater
Calls: rescind_invite_v1(p_invite_id) → fetch-pending-invite-list workflow
Writes: pendingInvites variable
Branches: confirm → rescind + close popup + refresh list | cancel → close popup only
Item: 10.8.11I3

---

## farm-area-add
Trigger: Add button on Workspace Settings Farm Areas tab
Reads: farm area name input value
Calls: create_farm_area_v1(p_area_name) → fetch-farm-area-list workflow
Writes: farmAreas variable, farm area name input (reset to empty)
Branches: none
Item: 10.8.11H

---

## farm-area-remove
Trigger: Delete button on farm area row
Reads: item.farm_area_id from farmAreas repeater
Calls: delete_farm_area_v1(p_farm_area_id) → fetch-farm-area-list workflow
Writes: farmAreas variable
Branches: none
Item: 10.8.11H

---


---

## fetch-seat-count
Trigger: Workspace Settings Billing section load (owner only)
Reads: entitlements variable (0237d4bd-5f1b-46d7-9851-19c0aadd695e)
Calls: none — reads active_seats from entitlements already loaded
Writes: none — display only
Branches: none — display only
Item: 10.8.11I6

---

## renew-now
Trigger: Renew Now link click on expired or expiring banner (owner only)
Reads: entitlements variable — can_manage_billing for visibility
Calls: none — navigate only
Writes: none
Branches: owner → navigate to Workspace Settings Billing | non-owner → link hidden
Item: 10.8.11L

---

## members-update-role
Trigger: Role dropdown change on Members tab member row (hidden for owner rows)
Reads: item.user_id, selected role value from workspaceMembers repeater
Calls: update_member_role_v1(p_user_id, p_role) → fetch-workspace-members workflow
Writes: workspaceMembers variable
Branches: none
Item: 10.8.11G

## Placeholder Workflows (confirm wiring before finalizing)

## public-form-resolve-slug
Trigger: Public intake form page load
Reads: URL slug parameter
Calls: check_slug_access_v1(p_slug) or equivalent public slug resolution RPC
Writes: formContext variable
Branches: slug valid → show form | slug invalid → show error
Item: 10.8.1
Note: PLACEHOLDER — confirm exact RPC, variable names, and error handling in WeWeb

---

## public-form-submit
Trigger: Submit button on public intake form
Reads: formContext variable, form field values
Calls: submit form RPC or Edge Function
Writes: none — side effect only
Branches: success → show confirmation | error → show field errors
Item: 10.8.1
Note: PLACEHOLDER — confirm exact RPC, payload shape, and error handling in WeWeb

---

## mao-calculator-save
Trigger: Save as deal / Sign in to save as deal button on /mao-calculator page
Reads: pluginVariables auth user, entitlements variable (0237d4bd) app_mode,
       input values for arv, repair, profit, multiplier, address
Calls: [AUTH CHECK] not authenticated → navigate to /auth
       [APP_MODE CHECK] app_mode != normal → navigate to /onboarding
       create_deal_v1(p_id, p_calc_version=1, p_assumptions) → navigate to /acquisition
Writes: none before RPC — deal written server-side
Branches: not authenticated → /auth | no subscription → /onboarding | entitled → save + /acquisition
Item: 10.9

---

## fetch-acq-kpis
Trigger: ACQ page load, date range pill click, custom date picker change
Reads: kpiDateFrom, kpiDateTo variables
Calls: get_acq_kpis_v1(p_date_from, p_date_to)
Writes: acqKpis variable
Branches: none
Item: 10.11B

---

## fetch-all-deals
Trigger: ACQ page load only
Reads: none (always fetches all with p_filter=all)
Calls: list_acq_deals_v1(p_filter='all', p_farm_area_id=null)
Writes: allDeals variable
Branches: none
Item: 10.11B

---

## fetch-acq-deals
Trigger: ACQ page load, stage filter click, farm area filter click
Reads: activeFilter, activeFarmAreaId variables
Calls: list_acq_deals_v1(p_filter=activeFilter, p_farm_area_id=activeFarmAreaId||null)
Writes: dealList variable
Branches: none
Item: 10.11B

---

## fetch-selected-deal
Trigger: deal row click, after save mutations
Reads: activeDealId variable
Calls: get_acq_deal_v1(p_deal_id=activeDealId)
Writes: selectedDeal variable
Branches: passthrough condition: activeDealId !== ''
Item: 10.11B

---

## send-to-dispo
Trigger: Confirm button in Send to Dispo popup
Reads: activeDealId, dispoAssignee variables
Calls: handoff_to_dispo_v1(p_deal_id=activeDealId, p_assignee_user_id=dispoAssignee)
Writes: none -- triggers fetch-acq-deals on success
Branches: success → close popup + fetch-acq-deals + clear activeDealId + clear selectedDeal
Item: 10.11B

---

## save-seller
Trigger: Save button in Edit Seller popup
Reads: seller input field values, activeDealId
Calls: update_deal_seller_v1(p_deal_id=activeDealId, p_fields=seller inputs)
Writes: none -- triggers fetch-selected-deal on success
Branches: success → fetch-selected-deal + close popup
Item: 10.11B

---

## save-property
Trigger: Save button in Edit Property popup
Reads: property input field values, activeDealId, deficiencyTags variable
Calls: update_deal_property_v1(p_deal_id, p_fields=address/next_action/next_action_due)
       update_deal_properties_v1(p_deal_id, p_fields=all property fields + deficiency_tags)
Writes: none -- triggers fetch-selected-deal on success
Branches: success → fetch-selected-deal + close popup
Item: 10.11B

---

## upload-deal-photos
Trigger: Upload button in Add Photo popup
Reads: uploadIndex variable, uploadedFiles variable, activeDealId, entitlements.data.tenant_id
Pattern: While loop with index variable

  - While condition: uploadIndex < uploadedFiles.length
  - Action 1: Supabase storage upload to deal-photos bucket
  - Action 2: register_deal_media_v1(p_deal_id, p_storage_path, p_sort_order=0)
  - Action 3: increment uploadIndex by 1
  - After loop: fetch-deal-media + close popup

Note: Binary data only accessible live from component variable, not storable in WeWeb variables.

While loop with index solves multi-file upload without JavaScript.

Item: 10.11B

---

## fetch-deal-media
Trigger: deal row click, after upload-deal-photos, after delete photo
Reads: activeDealId
Calls: list_deal_media_v1(p_deal_id=activeDealId)
Writes: dealMedia variable
Item: 10.11B

---

## fetch-deal-notes
Trigger: deal row click, after note submit
Reads: activeDealId
Calls: list_deal_notes_v1(p_deal_id=activeDealId)
Writes: dealNotes variable
Item: 10.11B

---

## fetch-deal-activity
Trigger: deal row click, after stage change, after mark dead, after handoff
Reads: activeDealId
Calls: list_deal_activity_v1(p_deal_id=activeDealId)
Writes: dealActivity variable
Item: 10.11B

---

## fetch-deal-reminders
Trigger: deal row click, after set reminder, after complete reminder
Reads: none (returns all tenant reminders, filtered client-side by activeDealId)
Calls: list_reminders_v1()
Writes: dealReminders variable
Item: 10.11B

---

## submit-deal-note
Trigger: Submit button in Notes/Log section
Reads: noteInput, activeDealId
Calls: create_deal_note_v1(p_deal_id, p_note_type='note', p_content=noteInput)
Writes: clears noteInput, triggers fetch-deal-notes
Item: 10.11B

---

## delete-deal-photo
Trigger: Delete button on each photo
Reads: activeDealId, media item id
Calls: delete_deal_media_v1(p_media_id)
Triggers: fetch-deal-media
Item: 10.11B

---

## public-form-page-load
Trigger: /form/{{slug}}/{{type}} page load
Reads: globalContext.page?.['path'].type, globalContext.page?.['path'].slug
Calls: none — route validation only
Writes: formState variable (b33bc3a6-01ab-4da5-93b6-70d198e78880)
Branches: type not in [seller, buyer, birddog] → formState=invalid_route | slug null/empty → formState=invalid_route | valid → formState=idle
Item: 10.12B

---

## submit-seller-form
Trigger: Seller form Submit button click on /form/{{slug}}/{{type}}
Reads: sellerAddressInput.value, sellerNameInput.value, sellerPhoneInput.value, sellerEmailInput.value, globalContext.page?.['path'].slug
Calls: submit_form_v1(p_slug=page.slug, p_form_type='seller', p_payload={address, name, phone, email, spam_token})
Writes: formState variable (b33bc3a6-01ab-4da5-93b6-70d198e78880), isSubmitting variable
Branches: any required field empty → formState=validation_error, stop | all filled → isSubmitting=true → RPC → success: formState=success, isSubmitting=false | error: formState=error, isSubmitting=false
Item: 10.12B

---

## submit-buyer-form
Trigger: Buyer form Submit button click on /form/{{slug}}/{{type}}
Reads: buyerNameInput.value, buyerEmailInput.value, buyerPhoneInput.value, buyerAreasInput.value, buyerBudgetInput.value, globalContext.page?.['path'].slug
Calls: submit_form_v1(p_slug=page.slug, p_form_type='buyer', p_payload={name, email, phone, areas_of_interest, budget_range, spam_token})
Writes: formState variable (b33bc3a6-01ab-4da5-93b6-70d198e78880), isSubmitting variable
Branches: name/email/phone empty → formState=validation_error, stop | all filled → isSubmitting=true → RPC → success: formState=success, isSubmitting=false | error: formState=error, isSubmitting=false
Item: 10.12B

---

## submit-birddog-form
Trigger: Birddog form Submit button click on /form/{{slug}}/{{type}}
Reads: birddogAddressInput.value, birddogNameInput.value, birddogPhoneInput.value, birddogEmailInput.value, birddogConditionInput.value, birddogAskingInput.value, globalContext.page?.['path'].slug
Calls: submit_form_v1(p_slug=page.slug, p_form_type='birddog', p_payload={address, name, phone, email, condition_notes, asking_price, spam_token})
Writes: formState variable (b33bc3a6-01ab-4da5-93b6-70d198e78880), isSubmitting variable
Branches: address/name/phone empty → formState=validation_error, stop | all filled → isSubmitting=true → RPC → success: formState=success, isSubmitting=false | error: formState=error, isSubmitting=false
Item: 10.12B

---

# WeWeb Variable Registry

All WeWeb variables by scope. Type icons: (i) = object, (T) = text, (o) = boolean.

## Global Variables

| Variable | Type | Description | Written By |
|----------|------|-------------|------------|
| deals_data | object | Origin unknown — possibly orphaned from early development. No workflow found writing to it. | unknown |
| entitlements | object | get_user_entitlements_v1() result — app_mode, subscription_status, role, can_manage_billing etc. Variable ID: 0237d4bd-5f1b-46d7-9851-19c0aadd695e | fetch-entitlements |
| error_message | text | General error message surface | various action workflows |
| gs_pendingIdempotencyKey | text | Idempotency key for create_tenant_v1() | onboarding-button |
| gs_selectedTenantId | text | Currently selected tenant ID for workspace switch | workspace-switcher |
| gs_slugCheckResult | object | check_slug_access_v1() result. Variable ID: 60ace435-0c5f-4a74-858f-9d6a4e2a1260 | fetch-slug-check-result |
| profileSettings | object | get_profile_settings_v1() result — user_id, email, display_name, has_used_trial. Variable ID: 4c345731-3d2f-4610-b69e-422394b064a0 | fetch-profile-settings |
| reset_email_sent | boolean | Flag: password reset email sent — set by reset password plugin page | reset password page |
| sign_in_error | text | Auth sign-in error message — set by auth/sign-in page | auth/sign-in page |
| success_message | text | General success message surface | various action workflows |

## Onboarding Variables

| Variable | Type | Description | Written By |
|----------|------|-------------|------------|
| is_loading | boolean | Loading state for onboarding button | onboarding-button |
| SLUG | text | Slug input value from onboarding Step 3 input field. Variable ID: 8654687c-8461-49a0-b3a3-f446d02cb55b. Input value ID: 9ec992f6-4cb8-402e-865a-38f4113c5112-value | bound to slug input |

## Workspace Settings Variables

| Variable | Type | Description | Written By |
|----------|------|-------------|------------|
| archivedWorkspaces | object | list_archived_workspaces_v1() result. Variable ID: 43bcf348-3de2-4369-b2d0-08b5c234d754 | fetch-archived-workspaces |
| farmArea | object | list_farm_areas_v1() result | fetch-farm-area-list |
| inviteRole | text | Selected role value in invite member form | bound to role dropdown |
| pendingInvite | object | list_pending_invites_v1() result | fetch-pending-invite-list |
| selectedRole | text | Selected role value in update member role dropdown | bound to role dropdown |
| showWorkspaceList | boolean | Controls visibility of workspace switcher list in hamburger | hamburger-switch-workspace |
| workspaceList | object | list_user_tenants_v1() result | fetch-workspace-list |
| workspaceMembers | object | list_workspace_members_v1() result | fetch-workspace-members |
| workspacesettings | object | get_workspace_settings_v1() result. Variable ID: 13fb0509-4a8f-4799-a4e8-2f491cd36ef6 | fetch-workspace-settings |

## ACQ Page Variables

| Variable | Type | Description | Written By |
|----------|------|-------------|------------|
| acqKpis | object | get_acq_kpis_v1() result — contracts_signed, leads_worked, lead_to_contract_pct, avg_assignment_fee. Variable ID: TBD | fetch-acq-kpis |
| activeDatePill | text | Active KPI date range pill — last7, last30, custom. Default: last30. Variable ID: a7c9995f-56f7-4978-8290-b83a2c515781 | date pill on-click |
| kpiDateFrom | text | KPI date filter start — ISO timestamp string. Variable ID: TBD | date pill on-click, custom date picker on-change |
| kpiDateTo | text | KPI date filter end — ISO timestamp string. Variable ID: TBD | date pill on-click, custom date picker on-change |
| activeFilter | text | Active stage filter — all, new, analyzing, offer_sent, follow_ups, under_contract. Default: all. Variable ID: TBD | stage filter pill on-click |
| activeFarmAreaId | text | Active farm area filter — sentinel value `all` or farm area UUID. Default: all. Variable ID: TBD | farm area pill on-click |
| allDeals | object | list_acq_deals_v1() result unfiltered — used for stage filter counts. Variable ID: TBD | fetch-all-deals |
| dealList | object | list_acq_deals_v1() result filtered by activeFilter and activeFarmAreaId. Variable ID: TBD | fetch-acq-deals |
| activeDealId | text | Currently selected deal UUID. Empty string when no deal selected. Variable ID: TBD | deal row on-click |
| selectedDeal | object | get_acq_deal_v1() result for activeDealId. Variable ID: d8580b53-ee7f-4dcd-b380-ec3c64475c9a | fetch-selected-deal |
| dispoAssignee | text | Selected assignee user_id for Send to Dispo popup. Variable ID: d93f58a4-0d4f-434d-ae5c-0f8d5e400735 | assignee repeater on-click |
| deficiencyTags | array | Working copy of deficiency tags in Edit Property popup. Loaded from selectedDeal on popup open. Variable ID: 7d8913b8-ed90-41c8-807a-b25d35376b54 | Edit button on-click, Add/Remove tag actions |
| uploadIndex | number | While loop counter for multi-file photo upload. Resets to 0 before each upload session. Variable ID: a26467b7-2a07-42d7-9aba-689a70d8e479 | upload-deal-photos while loop |
| uploadedFiles | array | File array from file upload component — used as while loop length reference. Variable ID: b7e2e745-5ebb-4c41-96e5-dae036d025ad | On change trigger of file upload element |
| dealMedia | object | list_deal_media_v1() result — photos for selected deal. Variable ID: 51bc8113-3aa8-4913-8221-ef59cc27c376 | fetch-deal-media |
| dealNotes | object | list_deal_notes_v1() result — notes for selected deal. Variable ID: 61f09425-563c-48ba-a62a-18de5ab34fec | fetch-deal-notes |
| dealActivity | object | list_deal_activity_v1() result — activity log for selected deal. Variable ID: a00c6fa3-ffce-49b5-8e4c-c177855ec11e | fetch-deal-activity |
| dealReminders | object | list_reminders_v1() result — all incomplete reminders for tenant. Variable ID: TBD | fetch-deal-reminders |

## Public Form Variables

| Variable | Type | Description | Written By |
|----------|------|-------------|------------|
| formState | text | Page: Public Form (/form/{{slug}}/{{type}}). Values: idle, validation_error, error, invalid_route, success. Controls visibility of SellerForm, BuyerForm, BirddogForm, ErrorState, SuccessState containers. Variable ID: b33bc3a6-01ab-4da5-93b6-70d198e78880. Item: 10.12B | public-form-page-load; submit-seller-form; submit-buyer-form; submit-birddog-form |
| isSubmitting | boolean | Page: Public Form (/form/{{slug}}/{{type}}). Values: true, false. Controls: submit button disabled state during RPC call. Item: 10.12B | submit-seller-form; submit-buyer-form; submit-birddog-form |
