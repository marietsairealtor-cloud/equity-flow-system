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

---

## 3) Deal Stages (AUTHORITATIVE — IMMUTABLE)

```
New → Analyzing → Offer Sent → Under Contract (UC) → Dispo → Closed / Dead
```

Rules:
- Closed and Dead are terminal states. Records become read-only.
- FUP tiers (2 Weeks, One Month, 90 Days) are eliminated. Follow-up timing handled by reminder engine.
- Stages track deal state. Reminders track nurture cadence. Clean separation.
- Auto-advance: one-tap actions automatically transition stages (e.g. "Send offer" moves Analyzing → Offer Sent).
- Valid transitions enforced server-side by `update_deal_v1`.

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
- Save as deal — calls `create_deal_v1` with calc inputs + calc_version + multiplier
- Generate offer copy — seller-ready text/email/PDF with dynamic 48-hour expiration clause
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
- Submissions pre-fill MAO draft for the deal (intake-to-MAO pipeline)
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
- Step 1: Create workspace
- Step 2: Pick workspace slug (lowercase, URL-safe, unique)
- Step 3: Subscribe via Stripe ($39 USD/seat/month, minimum 2 seats, optional annual toggle with 2 months free)

Notes:
- Joining an existing workspace is handled via email invite, resolved in `/post-auth` before onboarding is reached
- Invite acceptance is not an onboarding action
- Onboarding is shown only when entitlement state indicates it is required

Resume behavior: wizard detects current state from `get_user_entitlements_v1` and shows correct step. User who closed browser mid-payment returns to Step 3.

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
| 🔔 | Notifications | Gray | Reminders + submissions + buyer interest |
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

---

## 7) Today View (Default Landing)

User logs in and sees what needs attention now. Synthesized task list, not a pipeline to parse.

### 7.1 Layout
- Compact summary strip: pipeline deal count, total value, new leads, closing this week
- Task list: sorted by urgency
- Pipeline snapshot: compact stage count pills (New: N, Analyzing: N, etc.)

### 7.2 Task Sources (4 deterministic sources only)
- Overdue follow-ups (from reminder engine)
- Pending offers (Analyzing stage, MAO complete, no offer sent)
- Closing deadlines (UC/Dispo approaching close date)
- New intake submissions (pre-filled MAO drafts ready for analysis)

### 7.3 Deal Health Indicator

| Color | Meaning | Rule | Example |
|---|---|---|---|
| Red | Overdue | Activity gap > stage threshold | Offer sent 8 days ago, no response |
| Yellow | Stale | Activity gap approaching threshold | Analyzing 5 days, threshold 7 |
| Green | On track | Activity within expected cadence | UC deal, updated 2 days ago |

- Computed from `deals.updated_at` vs stage-specific thresholds
- No new table — derived from existing deal data
- Appears on Today view tasks AND Acquisition deal list

### 7.4 One-Tap Actions + Auto-Advance

| Task Type | Action Button | Advances Stage To | Behavior |
|---|---|---|---|
| Overdue follow-up | Follow up → | — | Native sms:/mailto: with pre-written copy |
| Offer ready | Send offer → | Offer Sent | Offer generator pre-filled, auto-advance |
| Closing deadline | Open TC → | — | Navigates to /tc/:deal_id |
| New lead | Analyze → | — | MAO pre-filled from intake submission |
| Buyer interest | View → | — | Deal detail with buyer notification context |

- Optimistic UI: task disappears instantly on action click, server processes in background
- Auto-advance: "Send offer" moves deal from Analyzing → Offer Sent automatically. User never manually updates a dropdown.

---

## 8) Content Pages

### 8.1 Acquisition (Full Pipeline)

- Summary strip: deal count by stage, pipeline value, lead volume (via allowlisted RPCs)
- Stage tabs: New | Analyzing | Offer Sent | UC | Dispo | Closed/Dead
- Farm area filter
- Deal list with health dots (red/yellow/green)
- Click deal → /acquisition/:deal_id sub-route for detail/edit view
- Deal detail: one-click Zillow/Redfin/Realtor.com links auto-generated from address
- All phone/email fields: native `tel:` / `sms:` / `mailto:` links
- Auto-advance: "Send offer" action moves deal Analyzing → Offer Sent automatically
- Cross-view transition toast when deal moves to different view
- Copy address icon next to every property address
- Quick-copy deal summary button (2-line teaser: address | ARV | ask)
- Follow-up reminders visible in deal detail
- Owner assignment, notes, timestamps per deal
- Activity log per deal via `foundation_log_activity_v1`
- Empty states per stage
- Data: `update_deal_v1` + `list_deals_v1` (CONTRACTS §5, §17)

### 8.2 Dispo Dashboard (Share Links Only)

- Displays deals in Dispo stage only
- Share link generation via `create_share_token_v1`
- Share link status (active / revoked / expired) visible per deal
- Revocation via `revoke_share_token_v1`
- Cross-view transition toast on stage transitions
- Activity log per deal
- NO buyer-deal matching (boundary line: no buyer CRM/Rolodex)

### 8.3 TC (Transaction Coordination)

- Route: /tc/:deal_id
- Progress % computed from checklist completion
- Days to close computed from closing_date
- Key dates: APS signed date, conditional deadline, closing date
- Closing checklist: APS signed, deposit received, sold firm, docs to lawyer, closing confirmed, assignment fee received
- Contract upload: single PDF slot (Supabase Storage). One file per deal. Not a document management system.
- On Close: "Actual assignment fee" input — compared to original MAO "desired profit" to show delta
- Immutable close: when deal stage = Closed or Dead, entire deal record + TC data becomes READ-ONLY. `update_deal_v1` rejects writes to terminal-stage deals.
- Assignment fee, sell price, buyer info section, notes

### 8.4 Lead Intake (Management)

- Authenticated management view at /lead-intake
- View submissions from public intake forms
- Copy form links per type (buyer, seller, birddog)
- Generate embed code for website integration
- Toggle form types on/off
- Empty state: when zero submissions, show prominent "Copy Seller Form Link" CTA button
- Separate from Acquisition — different user moment, different nav tab

### 8.5 Offer Generator

Component on MAO calculator page (authenticated context only). Not a separate page.
- Offer copy generated from MAO inputs + calc_version + multiplier
- Three output formats: Copy text | Copy email | Download PDF
- Dynamic 48-hour expiration clause auto-injected into all copy formats
- "Send offer" triggers Analyzing → Offer Sent stage transition via `update_deal_v1`
- Follow-up reminder auto-created on offer send (via reminder engine)

### 8.6 Intake-to-MAO Pre-fill

When a seller submits via the intake form with asking_price and/or repair_estimate:
- Values stored on draft deal record (created by `submit_form_v1`)
- Today view "Analyze →" opens MAO calculator with fields pre-filled from draft
- ARV defaults from asking_price (user can adjust), repairs default from self-reported estimate
- No re-entry, no loss of context

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
| Billing | Owner | Plan, payment method, cancel | Stripe. $39 USD/seat/month, min 2 seats, annual toggle. |

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

### 13.2 GUARDRAILS References
- §3 Prime Directive — all reads/writes via allowlisted RPCs only
- §5 No business logic in WeWeb
- §9 calc_version stored with every deal
- §11-14 RLS + Privilege Firewall enforced server-side
- §29 No `$$` in SQL

---

STATUS:
Aligned with Build Route v2.4
Aligned with Business Plan (Wholesale Hub)
Aligned with CONTRACTS
Aligned with GUARDRAILS
Three access tiers defined
Page inventory authoritative (10 + 2 settings + 1 error)
Deal stages authoritative (6 stages, terminal immutable)
Micro-friction features locked (12 + 7 technical)
Boundary lines locked (21 items)
Contract alignment documented
Governance stack consistent
