# WEWEB_ARCHITECTURE.md
Authoritative — UI Foundation Architecture (Build Route 10.8, Aligned with Business Plan)

---

## 0) Purpose

This document defines the complete WeWeb page architecture, access model, navigation, micro-friction features, and boundary lines for the Wholesale Hub product.

- Build Route defines what must be built and in what order.
- CONTRACTS defines RPC interfaces and security rules.
- GUARDRAILS defines enforcement rules.
- This document defines what the user sees and how they interact with it.

If conflict exists:
Build Route wins.
CONTRACTS wins.
GUARDRAILS wins.
This document must be updated via governance PR.

**Authority source:** WeWeb 10.8 Architecture Reference v6 FINAL
**Aligned with:** Wholesale Hub Business Plan
**Status:** LOCKED (changes only via PR + governance file)

---

## 1) Access Tiers (Three-Tier Model)

### 1.1 Open Public
Static URL, no credentials of any kind. Anyone on the internet can visit.
- MAO calculator (`/mao-calculator`)

### 1.2 Slug-Gated
Permanent URL with tenant slug. No authentication required. The slug resolves tenant context.
- Intake forms (`/form/:slug/:type`)

### 1.3 Token-Gated
Dynamic URL with share token. No authentication required. Token resolves deal context.
- Deal viewer (`/deal/:share_token`)

### 1.4 Authenticated
Supabase Auth session required. Tenant context resolved via `get_user_entitlements_v1`.
- All hub pages (Today, Acquisition, Dispo, TC, Lead Intake, Settings)

---

## 2) Page Inventory (AUTHORITATIVE)

| # | Page | Route | Access Tier | Gate Condition |
|---|---|---|---|---|
| 1 | MAO calculator | /mao-calculator | Open public + authenticated | None |
| 2 | Intake form | /form/:slug/:type | Slug-gated | Valid slug |
| 3 | Deal viewer | /deal/:share_token | Token-gated | Valid share token |
| 4 | Auth page | /auth | Public | None |
| 5 | Onboarding | /onboarding | Authenticated | Zero tenants or no active sub |
| 6 | Today | /today | Authenticated | Default landing |
| 7 | Acquisition | /acquisition (+ /:deal_id) | Authenticated | Full pipeline view |
| 8 | Dispo | /dispo | Authenticated | None |
| 9 | TC | /tc/:deal_id | Authenticated | None |
| 10 | Lead intake | /lead-intake | Authenticated | None |
| — | Profile settings | via Workspace ▾ dropdown | Authenticated | None |
| — | Workspace settings | via Workspace ▾ dropdown | Authenticated | Admin+ (role-gated tabs) |
| — | Error / 404 | catch-all | Universal | None |

**Note:** Notifications (🔔) is a shell-level drawer/component, not a standalone page.

---
## 3) Deal Stages (AUTHORITATIVE — IMMUTABLE)

New → Analyzing → Offer Sent → Under Contract (UC) → Dispo → TC → Closed / Dead

Rules:
- Closed and Dead are terminal states. Records become read-only.
- FUP tiers (2 Weeks, One Month, 90 Days) are eliminated. Follow-up timing handled by reminder engine.
- Stages track deal state. Reminders track nurture cadence. Clean separation.
- Auto-advance: one-tap actions automatically transition stages where applicable (for example, "Send offer" moves Analyzing → Offer Sent).
- Valid transitions enforced server-side by `update_deal_v1`.

### 3.1 Workflow Ownership + Handoff (AUTHORITATIVE)

Stage and assignee are separate concepts.

- `workflow_stage` tracks where the deal is in the lifecycle.
- `assignee_user_id` tracks who currently owns the next work step.
- Follow-up is not a stage. It is reminder-driven.
- Notifications are user-targeted through assignee / recipient, not role-targeted.

### 3.2 Handoff Rules (AUTHORITATIVE)

**Acq → Dispo**
- Available when deal is in `UC`
- User clicks **Send to Dispo**
- Small modal opens:
  - assignee dropdown
  - Confirm
  - Cancel
- On confirm:
  - `workflow_stage = Dispo`
  - `assignee_user_id = selected user`
  - deal leaves Acquisition view
  - assigned user receives notification

**Dispo → TC**
- Available only when both are true:
  - `assignment_agreement_signed_at` is set
  - `earnest_money_received_at` is set
- User clicks **Send to TC**
- Small modal opens:
  - assignee dropdown
  - Confirm
  - Cancel
- On confirm:
  - `workflow_stage = TC`
  - `assignee_user_id = selected user`
  - deal leaves Dispo view
  - assigned user receives notification
---

## 4) Public Surfaces

### 4.1 MAO Calculator (Dual-Route) — The Free Hook

**Inputs:**
- ARV (with address field for autocomplete)
- Repair estimate — quick toggles: Light ($15K) | Medium ($40K) | Heavy ($80K) + custom
- Desired profit / assignment fee
- MAO multiplier toggle: 70% | 75% | 80% (default 70%, stored with calc_version)

**Output:**
- Single MAO number: ARV × multiplier − repairs − profit
- Formula shown transparently below result

**Public context (no auth):**
- Route: /mao-calculator — standalone layout, no navbar
- Full results shown — no blur, no gate, no partial output
- CTA below result: "Save this deal + generate offer copy → Sign up free"
- Upgrade sells continuity, not access. User already got the answer.

**Authenticated context (paid user):**
- Same URL — renders inside authenticated shell with navbar
- **Dual-context rendering:** public and authenticated sessions use the same `/mao-calculator` page and components; layout chrome (standalone vs shell + navbar) switches on auth/session state only — no duplicate routes or forked calculators.
- **Backend-authoritative save:** “Save as deal” calls `create_deal_v1(p_id, p_calc_version, p_assumptions)` with the same assumption keys as the live calculator (`arv`, `repair_estimate`, `desired_profit`, `multiplier`, plus optional fields). The server computes `mao`, overwrites any client-supplied `mao`, and persists `deal_inputs.assumptions` with that value. The UI must treat the RPC success payload (and any subsequent reads) as the source of truth for saved MAO — not the pre-call client-side preview alone.
- Generate offer copy — seller-ready text/email/PDF with dynamic 48-hour expiration clause (must align copy with server-returned `mao` after save when a deal was just created).
- One-click context links: Zillow / Redfin / Realtor.com auto-generated from address
- All financial inputs: `inputmode="numeric"`, auto-format commas as typed

**Upgrade path:**
1. Visit /mao-calculator (public)
2. Run calc, get full result
3. Click CTA
4. Auth → onboarding (workspace + slug + subscribe)
5. Land on Today view with saved deal

### 4.2 Intake Form (Slug-Gated)

- Route: /form/:slug/:type where type is buyer, seller, or birddog
- Slug resolves tenant context via `resolve_form_slug_v1` RPC (anon-callable)
- No expiration, no token renewal — permanent URLs suitable for website embedding
- Submissions route to tenant inbox via `submit_form_v1` RPC (anon-callable)
- Seller form captures: address, asking price, self-reported repairs, condition notes, timeline
- Buyer form captures: name, email, phone, areas of interest, budget range
- Birddog form captures: property address, owner info, condition notes, asking price if known
- Address autocomplete on all address fields (Google Places)
- Invisible spam protection (Cloudflare Turnstile or reCAPTCHA v3)
- Address-based seller and birddog submissions may create or pre-fill MAO draft deals (intake-to-MAO pipeline); buyer submissions remain intake records only
- One page component, dynamic rendering based on form type

### 4.3 Deal Viewer (Token-Gated) — Buyer-Ready Deal Packet

- Route: /deal/:share_token
- Displays: ARV, repairs, assignment ask, terms, photos/notes
- Tenant branding: workspace name auto-displayed at top (zero config)
- "I'm Interested" CTA at bottom: mailto: pre-filled with deal address + wholesaler email
- Notification bell pinged on buyer click (best-effort via `foundation_log_activity_v1`)
- Mobile-friendly
- Token resolved via `lookup_share_token_v1` (CONTRACTS §17)
- Tokens expire (≤90 days), are revocable, scoped to deal_id
- Expired/revoked/invalid: friendly "This deal is no longer available" page (anti-enumeration)

### 4.4 URL Patterns

| URL Pattern | Type | Expires |
|---|---|---|
| /form/acme-realty/seller | Slug (permanent) | Never |
| /form/acme-realty/buyer | Slug (permanent) | Never |
| /form/acme-realty/birddog | Slug (permanent) | Never |
| /deal/shr_9f3a... | Share token | ≤90 days |
| /acquisition/:deal_id | Auth sub-route | Session |
| /tc/:deal_id | Auth sub-route | Session |

### 4.5 Slugs vs Tokens (Separate Systems)

Share tokens (Section 8) = temporary, deal-specific access. Used by Dispo for buyer deal packets. Expire ≤90 days, revocable, scoped to deal_id.

Slugs (new) = permanent, tenant-scoped form URLs. Used by Lead Intake for intake forms. No expiration, embeddable on websites. Different mechanism, different use case, no overlap.

---
## 5) Authentication and Onboarding

### 5.1 Auth Page

Single auth page at /auth handling all states via Supabase Auth plugin:
- Login (email/password)
- Signup (new account)
- Password reset (token in URL hash, handled natively)
- Invite entry point: invite email link may still land on `/auth` with `?token=...` for context/display, but token is NOT the primary acceptance authority after auth
- After auth completes, `/post-auth` resolves pending invites server-side via `accept_pending_invites_v1()`

Auth page responsibilities:
- authenticate the user
- redirect authenticated user into the post-auth routing flow
- no direct table calls
- no invite acceptance logic in WeWeb beyond standard auth entry/redirect behavior

Invite acceptance authority:
- exact email match only
- backend reads authenticated email from `auth.users.email` via `auth.uid()` inside `accept_pending_invites_v1()`
- no frontend-supplied email parameter
- token in invite URL is optional context only, not the primary post-auth acceptance mechanism

### 5.2 Onboarding Wizard

Single page at /onboarding with sequential steps:

- Step 1: Enter workspace slug
- Step 2: Resolve slug and branch
- Step 3: Subscribe via Stripe ($39 USD/seat/month), redirect to "Today"

**Slug Resolution Behavior (Authoritative):**

- On submit, system calls `check_slug_access_v1(p_slug)`
- Branching rules:
  - slug not taken → create tenant → set slug → proceed to subscription
  - slug taken + user is owner/admin → resume subscription for that workspace (no tenant creation)
  - slug taken + user not owner/admin → show "Workspace URL is already taken"
- Slug check occurs **before any tenant creation**
- Onboarding must not create duplicate tenants for the same slug
- Slug ownership is enforced server-side only (no frontend inference)

Notes:
- Joining an existing workspace is handled via email invite, resolved in `/post-auth` before onboarding is reached
- Invite acceptance is not an onboarding action
- Onboarding is shown only when entitlement state indicates it is required

Resume behavior:
- If user returns mid-payment, Step 3 resumes using the same workspace (no new tenant created)
- Routing is determined by `get_user_entitlements_v1`

### 5.3 Gate Logic on Authenticated Page Load

Authoritative post-auth order:

1. Auth completes
2. `/post-auth` calls `accept_pending_invites_v1()`
3. `/post-auth` calls `get_user_entitlements_v1()`
4. `get_user_entitlements_v1` → no memberships → onboarding Step 1
5. `get_user_entitlements_v1` → membership exists, no active sub → onboarding Step 3
6. `get_user_entitlements_v1` → membership + active/expiring sub → Today view (skip entirely)
7. Subscription lapse mid-session → expired banner overlay (not a redirect)

Pending invite resolution rules:
- exact email match only
- valid pending invites are auto-accepted oldest-first
- if `current_tenant_id` already exists, do not auto-switch it
- if `current_tenant_id` is NULL, oldest successfully accepted invite becomes current tenant
- duplicate/already-member cases are treated as already satisfied
- partial acceptance is allowed
- failures are silent to the user
- routing still comes only from entitlement state after invite resolution
---

## 6) Authenticated Shell

### 6.1 Navbar (AUTHORITATIVE order)

| Nav Item | Page | Color | Notes |
|---|---|---|---|
| Today | Today view | Amber | DEFAULT LANDING |
| MAO | MAO calculator | Green | Dual-route + offer gen + toggles + multiplier |
| Acquisition | Acquisition | Purple | Pipeline + health dots + auto-advance |
| Dispo | Dispo dashboard | Purple | Share link management |
| TC | Transaction coord. | Purple | /tc/:deal_id + checklist + contract upload |
| Lead intake | Lead intake mgmt | Blue | Submissions, form links, embeds |
| 🔔 | Notifications | Gray | Drawer/component only. Shows reminders, new intake submissions, buyer interest, closing alerts, and deal handoff notifications ("deal assigned to you"). |
| Workspace ▾ | Account dropdown | Coral | Switch workspace, settings, profile, sign out |

Mobile: navbar collapses to hamburger menu. Workspace dropdown remains accessible.

### 6.2 Expired Subscription Banner

Component (not a page) rendered at top of authenticated shell. Two states:

- **Warning (≤5 days before expiration):** "Your subscription expires in X days. [Renew now →]" — soft, informational. All features remain functional.
- **Expired (after lapse):** "Subscription expired. [Renew now →]" — RPCs return NOT_AUTHORIZED server-side.

`get_user_entitlements_v1` returns `subscription_status` = 'expiring' when ≤5 days remain (computed server-side). WeWeb checks the status string only — no date math in frontend. GUARDRAILS §5: no business logic in WeWeb.

### 6.3 Workspace ▾ Dropdown

Single merged dropdown (no separate User menu). Contains:
- Switch workspace — shows tenant list, writes `gs_selectedTenantId` (CONTRACTS §4), updates `user_profiles.current_tenant_id` (CONTRACTS §3), refetches `get_user_entitlements_v1`. No page navigation — data reloads in place.
- Workspace settings (admin+ only)
- Profile settings (all users)
- Sign out

### 6.4 Notifications Drawer Behavior

Notifications are user-targeted, not broad role spam.

Examples:
- reminder due
- new intake submission
- buyer interest
- closing alert
- deal assigned to you

Deal handoff notifications include:
- address
- from who
- destination lane
- click opens the correct page and deal

---

## 7) Today View (Default Landing)

**Purpose**
Today is the executive overview and triage page. It shows what matters now, where deals are stuck, and what requires action today. It is not a full workflow page. Its job is to summarize the business and route the user into the correct working page with one click.

### 7.1 Layout

* Compact summary strip with the top 3 business KPIs only:

  * Projected Fees
  * Overdue Follow-Ups
  * Closings This Week
* Pipeline snapshot with clickable stage count pills:

  * New
  * Analyzing
  * Offer Sent
  * UC
  * Dispo
  * TC
* Needs Attention Now list:

  * sorted by urgency
  * one row per deal/task
  * one primary action per row

### 7.2 Task Sources (deterministic only)

* overdue Acq follow-ups
* overdue Dispo follow-ups
* pending offers
* TC-stage closing deadlines / at-risk closings
* new address-based intake submissions and internal lead-intake entries ready for analysis
* buyer interest on dispo deals

### 7.3 Each task row must show

* address
* current stage
* owner
* reason it is here
* age or due time
* one primary action button

### 7.4 One-Tap Actions

* Follow Up → opens Acquisition on that deal
* Send Offer → opens Offer Generator / Acquisition and auto-advances when sent
* Analyze → opens MAO / Acquisition with intake pre-fill
* Open TC → opens `/tc/:deal_id`
* View → opens Dispo or deal detail with buyer-interest context

### 7.5 Design rule

Today must prioritize exceptions and movement, not vanity metrics.
The page should help the user decide what to act on first and route them into the correct page immediately.

---

## 8) Content Pages

### 8.1 Acquisition

**Purpose**
Acquisition is the seller-side workbench. Acq works the deal until it is ready to be handed to Dispo.

**Ownership rule**
Acquisition view is ownership-scoped.
It shows only deals still in the Acq working lane:
- New
- Analyzing
- Offer Sent
- UC
- Follow-ups (derived reminder filter, not a stage)

Once a deal is sent to Dispo, it is removed from Acquisition immediately.

**What the page shows**
- Top 3 KPIs:
  - Contracts signed
  - Lead-to-contract %
  - Avg projected assignment fee
- Filters:
  - All
  - New
  - Analyzing
  - Offer Sent
  - UC
  - Follow-ups
- Farm area filter
- Deal list with health dots
- Click deal → `/acquisition/:deal_id` sub-route for detail/edit view

**Deal detail**
- seller pain / motivation
- property condition summary
- pricing snapshot
- close angle
- current objection / blocker
- next action + due time
- quick contact actions near top:
  - Call
  - Text
  - Email
- one-click Zillow / Redfin / Realtor.com links
- copy address icon
- quick-copy deal summary button
- reminders
- notes
- owner assignment
- timestamps
- activity log
- Users do not manually choose from a generic status dropdown. The UI shows only valid next-step action buttons for the current stage.


**Actions**
- In `Analyzing`, primary CTA is **Send offer → Offer Sent**
- In `UC`, primary CTA is **Send to Dispo**
- **Send to Dispo** opens a small modal:
  - assignee dropdown
  - Confirm
  - Cancel
- On confirm:
  - stage moves to `Dispo`
  - assignee is saved
  - deal leaves Acquisition
  - assigned user gets notification

**Data**
- `update_deal_v1` + `list_deals_v1`
- reminders from reminder engine

---

### 8.2 Dispo Dashboard (Share Links Only)

**Purpose**
Dispo is for deals already in the Dispo stage.
Its job is to generate and manage buyer-facing share links for specific deals. 

**What this page does**

* shows deals in Dispo stage only
* creates share links via `create_share_token_v1`
* shows link status: active / revoked / expired
* revokes links via `revoke_share_token_v1`
* shows activity log per deal
* shows cross-view transition toast on stage changes 

**Boundary**

* no buyer CRM
* no buyer-deal matching
* no Rolodex 

**Primary KPIs (Top 3 only)**

* Deals Moved to TC
* Deposit / Earnest Money / Consideration Collected
* Avg Assignment Fee

---
### 8.3 TC (Transaction Coordination)

**Purpose**
TC owns the file after Dispo handoff and drives it to closing and cash in bank.

**Ownership rule**
TC operates on deals in `TC` stage only.

**What the page shows**
- Top 3 KPIs:
  - Closings this week
  - Closed assignment fee received
  - At-risk closings
- Route: `/tc/:deal_id`
- progress % computed from checklist completion
- days to close computed from closing_date
- key dates:
  - APS signed date
  - conditional deadline
  - closing date
- closing checklist:
  - APS signed
  - deposit received
  - sold firm
  - docs to lawyer
  - closing confirmed
  - assignment fee received
- contract upload: single PDF slot
- actual assignment fee vs original desired profit delta
- assignment fee, sell price, buyer info, notes
- activity log

**Entry into TC**
A deal enters TC only through Dispo handoff:
- assignment agreement signed
- earnest money received
- Send to TC confirmed
- assignee selected
- assigned user receives notification

**Read-only rules**
- all non-TC fields are effectively frozen once deal is in TC
- when deal stage = Closed or Dead, entire deal record + TC data becomes read-only
---

### 8.4 Lead Intake (Management)

**Purpose**
Lead Intake is the authenticated intake-management page.
It is the inbox and control center for public intake forms and submissions. 

**This page is separate from Acquisition because**

* Lead Intake is for receiving and managing incoming leads
* Acquisition is for working those leads through the pipeline 

**What this page does**

* shows submissions from public intake forms
* supports internal lead-intake entry for address-based leads
* copies form links for buyer / seller / birddog
* generates website embed code
* toggles form types on or off
* shows strong empty state CTA when there are no submissions:

  * “Copy Seller Form Link” 

**Route**

* `/lead-intake`

**Primary KPIs (Top 3 only)**

* New Leads
* Unreviewed Submissions
* Submission-to-Deal %

---

### 8.5 Offer Generator

**Purpose**
The Offer Generator turns MAO-approved numbers into seller-ready offer copy.
It lives on the MAO calculator page in authenticated context. It is not a separate page. 

**What it does**

* generates offer copy from MAO inputs + `calc_version` + multiplier
* supports:

  * Copy text
  * Copy email
  * Download PDF
* injects dynamic 48-hour expiration clause into all outputs
* “Send offer” triggers Analyzing → Offer Sent via `update_deal_v1`
* auto-creates follow-up reminder on offer send 

**Reporting note**

* Offer Generator metrics roll up under Acquisition KPIs.
* Offer Generator does not create separate department KPI ownership.

---

### 8.6 Intake-to-MAO Pre-fill

**Purpose**
Intake-to-MAO pre-fill removes duplicate entry between seller submission and first analysis. 

**What it does**
When a seller submits a form with `asking_price` and/or `repair_estimate`:

* `submit_form_v1` stores those values on the draft deal
* Today view “Analyze →” opens MAO with those values pre-filled
* ARV defaults from asking price and can be adjusted
* repairs default from self-reported estimate
* no re-entry
* no context loss 

**Reporting note**

* Intake-to-MAO pre-fill is a pipeline behavior, not a standalone department KPI surface.
* Related operational metrics may roll up under Lead Intake and Acquisition reporting.

Two notes so you don’t accidentally build nonsense:

* **Lead Intake KPIs are intake KPIs, not full marketing KPIs.** Marketing spend, cost per lead, and cost per contract belong in a separate marketing / finance reporting layer, not this page.
* **Dispo and TC split money ownership by phase.** Dispo owns deposit / earnest money / consideration collection before TC handoff. TC owns closing execution and closed money in bank.

### 8.7 KPI Definitions (AUTHORITATIVE)

Use these definitions unless a governance PR changes them.

**Default reporting windows**
- **Today page KPIs:** real-time / current-state values
- **Department page KPIs:** month-to-date values unless explicitly overridden by a reporting filter

- **Projected Fees:** Sum of the authoritative projected assignment fee field for all active deals in stages New through TC. Blank values count as 0. Excludes Closed and Dead.
- **Overdue Follow-Ups:** Count of open Acq- or Dispo-owned reminder tasks whose due time has passed and whose deals are still active. Excludes TC closing deadlines and checklist items.
- **Closings This Week:** Count of deals in TC with `closing_date` within the tenant-local current calendar week and not yet Closed or Dead.
- **New Leads:** Count of new intake submissions / internal lead-intake entries created during the selected reporting period.
- **Unreviewed Submissions:** Count of intake submissions / internal lead-intake entries not yet marked reviewed by a user.
- **Submission-to-Deal %:** Distinct property addresses from address-based intake sources that became deals ÷ distinct property addresses submitted through address-based intake sources during the selected reporting period. One property address counts once even if submitted multiple times. Buyer submissions are excluded because they are not property-address based in the current form design.
- **Address dedup rule:** Address-based intake records are deduplicated by the system-normalized property address key. Street abbreviations and formatting variants collapse to the same address; distinct unit numbers count as distinct addresses; missing unit numbers do not merge with known unit-specific records unless governance changes the matching rule.
- **Contracts Signed:** Count of deals with contract signed date recorded during the selected reporting period.
- **Leads Worked:** Count of deals with at least one logged Acquisition activity during the selected reporting period.
- **Lead-to-Contract %:** Contracts Signed ÷ Leads Worked.
- **Avg Projected Assignment Fee / Projected Gross Profit:** Average projected assignment fee on deals that reached contract signed / UC during the selected reporting period.
- **Deals Moved to TC:** Count of deals transitioned from Dispo to TC during the selected reporting period. A deal enters TC only when the assignment agreement is signed and deposit / earnest money / consideration is received.
- **Deposit / Earnest Money / Consideration Collected:** Total deposit / earnest money / consideration amount recorded as received before TC handoff during the selected reporting period on Dispo-owned deals. Deposit collection is fully owned by Dispo because deposit must be received before the deal can move to TC.
- **Avg Assignment Fee (Dispo):** Average assignment fee on deals moved from Dispo to TC during the selected reporting period.
- **Closed Assignment Fee Received:** Total assignment fee amount recorded as received on deals marked Closed during the selected reporting period.
- **At-Risk Closings:** Count of TC-stage deals with closing date within 7 days and missing required checklist items, overdue checklist items, or passed closing date without being marked Closed.
- **Dead reason required:** A deal may move to Dead from any active non-terminal stage only if a dead reason is recorded. Standard reasons: house sold, seller requested no contact, seller withdrew, duplicate, invalid lead, other.

### 8.8 Movement Definition (AUTHORITATIVE)

A deal is considered “moved” only when a user action materially advances seller qualification, pricing certainty, offer status, contract status, buyer exposure, deposit status, or closing progress. Busywork does not count as movement.

Examples of movement:
- seller pain captured
- property condition clarified
- MAO confirmed
- offer sent
- contract signed
- deal moved to Dispo
- deposit / earnest money / consideration received
- deal moved to TC
- closing checklist milestone completed
- deal closed
- deal marked Dead with reason

---

## 9) Settings

### 9.1 Profile Settings

User-scoped. Accessible via Workspace ▾ dropdown. All authenticated users.
- Display name, email
- Password change (Supabase Auth)
- Notification preferences

### 9.2 Workspace Settings (Role-Gated Tabs)

Tenant-scoped. Accessible via Workspace ▾ dropdown.

| Tab | Role Required | Fields | Notes |
|---|---|---|---|
| General | Admin+ | Name, slug, country, currency, measurement unit, farm areas | Text-based farm areas (no map polygons). Tenant-level international support. |
| Members | Admin+ | Invite, remove, change roles | Owner / Admin / Member only. Flat roles. |
| Billing | Owner | Plan, payment method, cancel | Stripe. $39 USD/seat/month|

Timezone: tenant-level setting (single dropdown).

---

## 10) Error Handling

- Invalid slug → "Workspace not found" (friendly message)
- Expired/revoked share token → "This deal is no longer available" (polite, anti-enumeration — identical page regardless of failure reason)
- Invalid route → 404 page (clean design)
- Subscription expired mid-session → Banner overlay (not redirect)
- No tenant context → Onboarding wizard
- All error pages: no stack traces, no developer jargon, no raw error codes

---

## 11) Micro-Friction Features (AUTHORITATIVE)

Zero-config features. No setup required from the user.

### 11.1 Data Entry Speed
- Address autocomplete (Google Places API) on: MAO calculator, intake forms, deal detail
- Repair quick toggles: Light ($15K) | Medium ($40K) | Heavy ($80K) + custom input
- Adjustable MAO multiplier: 70% | 75% | 80% toggle (stored with calc_version)
- `inputmode="numeric"` on all financial inputs (mobile numeric keyboard)
- Auto-format currency with commas as typed (350000 → 350,000)

### 11.2 Communication Speed
- Native `tel:` links on every phone number (opens dialer)
- Native `sms:` links on every phone number (opens texting app with pre-written copy)
- Native `mailto:` links on every email (opens email client with pre-written copy)
- Today view "Follow up" action uses sms:/mailto: with offer copy pre-inserted
- Deal viewer "I'm Interested" uses mailto: for buyers

### 11.3 Research Speed
- One-click context links: Zillow / Redfin / Realtor.com auto-generated from property address
- Copy address icon next to every property address (Acquisition, TC, Lead Intake)
- Quick-copy deal summary: one button copies 2-line teaser (address | ARV | ask)

### 11.4 Output Formats
- Offer generator: Copy text | Copy email | Download PDF
- Dynamic 48-hour expiration clause in all offer copy

### 11.5 Data Pipeline
- Intake-to-MAO pre-fill: seller submissions auto-draft MAO numbers
- Auto-advance stages: one-tap actions automatically transition deal stages
- Optimistic UI: Today view tasks disappear instantly on action

### 11.6 Presentation
- Tenant branding: workspace name on Deal Viewer (zero config)

### 11.7 Safety
- Invisible spam protection on public intake forms (Cloudflare Turnstile or reCAPTCHA v3)
- Immutable Closed/Dead records (read-only lock on terminal states)
- Empty state on Lead Intake: "Copy Seller Form Link" CTA when zero submissions
- Actual vs estimated assignment fee comparison on TC close

---

## 12) Boundary Lines — DO NOT BUILD (AUTHORITATIVE)

These apply to ALL Section 10 items. Each is explicitly rejected with rationale tied to the business plan.

### 12.1 Workflow
- **No custom pipeline stages.** Breaks health dots, Today view task routing, stage-based thresholds. Stages are authoritative. "Predictable states and transitions."
- **No generic to-do lists.** Today view is deterministic. Tasks come from deal state and reminders, not user-typed notes. This is a deal engine, not a notepad.
- **No complex task dependencies or approval workflows.** Target is solo operators and tiny teams. Enterprise approval chains paralyze a 2-person outfit.
- **No lead routing or round-robin assignment.** Submissions hit tenant inbox for whole team to see. "Mom-and-Pop Power."
- **No automated drip campaigns.** Reminder engine reminds, user pushes the button. One action, not a workflow. "Respect Energy."

### 12.2 Communication
- **No built-in calling, Twilio, or SMS infrastructure.** Native `tel:` / `sms:` / `mailto:` links handle this. A2P 10DLC compliance is not our problem.
- **No in-app messaging or chat.** The phone is the communication tool.
- **No two-way email sync (IMAP/SMTP).** No unified inbox. Use native email client.

### 12.3 Integration
- **No Zapier or webhooks for V1.** Force users to live in the hub to prove core value. Integrations reconnect the scatter.
- **No automated comp integrations (PropStream/Zillow API).** Business plan: "Comps can be manual V1." Manual ARV.
- **No in-app e-signatures (DocuSign/HelloSign).** TC is a checklist tracker, not a signing suite.

### 12.4 UI Complexity
- **No custom fields or flexible schema.** Breaks aggregation, health dots, determinism. "Order = Safety."
- **No custom form builders or drag-and-drop.** Hardcoded intake fields map predictably to database.
- **No visual map interfaces or polygon drawing for farm areas.** Text-based tags only.
- **No in-app image editing or cropping.** Upload raw photos from phone. No rotation/filter tools.
- **No granular user permissions.** Owner / Admin / Member only. No per-deal, per-zip, per-stage visibility matrices.
- **No cash buyer CRM or Rolodex.** Dispo is share links for specific deals, not a massive buyer database.

### 12.5 Technical
- **No complex calculators (BRRRR, rental yield, refi, cap rate).** MAO formula only. Target is wholesalers, not buy-and-hold investors.
- **No per-deal currency toggles.** Currency is tenant-level. If workspace is CAD, everything is CAD.
- **No per-user timezone settings.** Tenant-level or browser-local.
- **No offline mode, PWA, or local-first database sync.** Standard API calls. "Time-boxed builds + stop rules."

---

## 13) Contract Alignment

### 13.1 CONTRACTS References
- §3 Tenancy Resolution — `current_tenant_id()` resolves tenant context
- §4 UI State Contract — `gs_selectedTenantId` allowed (UI routing cache only, never authorization)
- §5 Pagination Contract — `list_deals_v1` with cursor pagination
- §5A Entitlement RPC — `get_user_entitlements_v1` for gate logic (extended with subscription_status) returns `subscription_status` (active | expiring | expired | none) and `subscription_days_remaining` (integer). Expiration threshold computed server-side. Frontend displays only.
- §8 SECURITY DEFINER Safety — all RPCs follow safety rules
- §9 Helper Function Exposure — `require_min_role_v1` for role gating
- §12 Privilege Firewall — core tables not readable by anon/authenticated. Controlled exception for `resolve_form_slug_v1` and `submit_form_v1` (anon-callable).
- §17 RPC Mapping — all data calls via registered RPCs only. New RPCs registered.
- §52 Archived Workspace Restore Targeting — `list_archived_workspaces_v1`, `restore_workspace_v1(p_restore_token)`; onboarding archived recovery and `create-restore-checkout-session` Edge Function per CONTRACTS §52 and Build Route 10.8.11P.

### 13.2 GUARDRAILS References
- §3 Prime Directive — all reads/writes via allowlisted RPCs only
- §5 No business logic in WeWeb
- §9 calc_version stored with every deal
- §11-14 RLS + Privilege Firewall enforced server-side
- §29 No `$$` in SQL

## 14) Expired, Archived, Restore, and Recovery Flow

**Build Route 10.8.11P (authoritative UI wiring):** All behavior in this section is driven by `get_user_entitlements_v1` and governed RPCs only — no client-side subscription grace-period math, no client-invented archive state. `app_mode` is the primary routing signal (`normal` | `read_only_expired` | `archived_unreachable`).

Workspace access has three distinct states.

### 14.1 Read-only expired

A workspace is **read-only expired** when billing has lapsed but the 60-day grace window has not yet ended.

Behavior:

- users may still enter the authenticated app shell
- pages may remain viewable
- write/save/create/update/send/complete/upload affordances are disabled (backend write lock is authoritative; UI mirrors entitlement state)
- billing remains available to the workspace owner via **Manage billing**; admin/member do not get actionable billing controls
- the expired banner is shown

Universal message:

- `Subscription expired. This workspace is read-only. Renew within 60 days to avoid data loss.`

Recovery:

- if the owner renews during this 60-day window, the workspace returns to normal automatically after billing sync completes

### 14.2 Archived / unreachable

A workspace becomes **archived / unreachable** after the 60-day grace window ends.

Behavior:

- workspace is not reachable by any user
- archived workspace is not rendered as normal read-only mode
- archived users are treated as having no reachable workspace
- post-auth routing behaves like a user without a reachable workspace
- onboarding may be shown again

Important:

- archived is not the same as read-only expired
- payment alone does not reopen an archived workspace

Recovery:

- if the owner renews after archive, the workspace remains archived
- archived workspace requires an explicit **Restore workspace** action
- restore is allowed only when:
  - the workspace is archived
  - the workspace has not been hard deleted
  - billing is active again

### 14.3 Hard deleted

A workspace is **hard deleted** 6 months after archive begins.

Behavior:

- workspace data is permanently removed
- no user can access the workspace
- no restore is possible

### Routing summary

- read-only expired → user may still enter app shell in restricted mode
- archived / unreachable → user treated as having no reachable workspace
- hard deleted → no workspace remains to restore

### Billing summary

- owner-only **Manage billing** remains the billing entry point
- renew before archive → automatic recovery
- renew after archive → explicit restore required
- renew after hard delete → no recovery

---

### Archived workspace recovery (onboarding)

Onboarding supports two owner-facing paths only:

1. **Create workspace**
2. **Archived workspaces**

There is **no self-serve Join workspace flow**.
Access to another workspace is invite-only because the workspace owner pays for seats.

#### Archived workspaces section

If the authenticated user owns one or more archived workspaces, onboarding must show an **Archived workspaces** section.

The list is populated from `list_archived_workspaces_v1` (owner-scoped; not JWT current-tenant scoped). Each row includes `restore_token` for downstream restore or checkout.

For each archived workspace, show:

- workspace name
- slug
- archive status
- billing state
- action button based on billing state

Button behavior:

- if billing is inactive: **Subscribe to restore workspace** — WeWeb calls the Edge Function `create-restore-checkout-session` with the user’s bearer token and the selected row’s `restore_token` in the request body. The function validates the token against `list_archived_workspaces_v1`, creates a Stripe Checkout session for that tenant, and sets `success_url` / `cancel_url` back to `/onboarding` with `restore_checkout=success` or `restore_checkout=canceled` (distinct from new-workspace checkout which uses `create-checkout-session` and lands on `/today` on success).
- if billing is active again: **Restore workspace** — WeWeb calls `restore_workspace_v1(p_restore_token)` with that row’s `restore_token`. On success, refetch `get_user_entitlements_v1` and resume normal reachable-workspace routing. No UI-only “unarchive” mutation.

#### Restore behavior

Restore must **not** depend on the archived workspace being the current tenant context.

Restore is initiated from the onboarding archived-workspaces list.
The user selects a specific archived workspace to restore.

Restore is allowed only when:

- the caller is the owner of that archived workspace
- the workspace is archived
- the workspace has not been hard deleted
- billing is active again

#### Post-auth routing

`app_mode` is the primary routing signal.

Routing rules:

- `normal` → normal reachable workspace flow
- `read_only_expired` → authenticated shell in restricted/read-only mode
- `archived_unreachable` → if user has no reachable workspace, route to onboarding

If the user has archived owned workspaces but no reachable workspace, onboarding must show the **Archived workspaces** section.

#### Important distinction (quick reference)

- **Read-only expired** = workspace still reachable, billing can recover access automatically
- **Archived** = workspace unreachable, payment alone does not reopen it
- **Hard deleted** = workspace permanently gone, no restore possible

---

STATUS:
Aligned with Build Route v2.4
Aligned with Business Plan (Wholesale Hub)
Aligned with CONTRACTS
Aligned with GUARDRAILS
Three access tiers defined
Page inventory authoritative (10 + 2 settings + 1 error)
Deal stages authoritative (7 stages including TC, terminal immutable)
Micro-friction features locked (12 + 7 technical)
Boundary lines locked (21 items)
Contract alignment documented
Governance stack consistent
