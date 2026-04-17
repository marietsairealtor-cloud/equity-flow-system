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