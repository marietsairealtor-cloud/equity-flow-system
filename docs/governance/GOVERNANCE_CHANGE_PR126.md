# GOVERNANCE_CHANGE_PR126.md

## Build Route Item
10.8.1 — Slug System (Forms Infrastructure)

## Governance Surface Touched
- `docs/artifacts/CONTRACTS.md` §12 — controlled exception documented for anon EXECUTE on resolve_form_slug_v1 and submit_form_v1
- `docs/artifacts/CONTRACTS.md` §17 — RPC mapping table updated with resolve_form_slug_v1 and submit_form_v1

## Justification
10.8.1 introduces two anon-callable RPCs required for public intake form URLs.
These RPCs must be callable without authentication — slug-gated forms are
permanent public URLs suitable for website embedding (WEWEB_ARCHITECTURE §4.2).

CONTRACTS §12 controlled exception is warranted because:
- resolve_form_slug_v1 returns only tenant_id — no internal identifiers exposed
- submit_form_v1 resolves tenant internally from slug — no tenant_id param
- Both are SECURITY DEFINER with fixed search_path per CONTRACTS §8
- Spam protection token required on all submissions (submit_form_v1)
- No existence leak between form types (resolve_form_slug_v1)

## No Breaking Changes
- No existing RPC signature changes
- No schema changes to existing tables
- New tables: tenant_slugs, draft_deals (both RLS ON, REVOKE from anon/authenticated)

## Status
Implementation complete. Tests: 23/23 PASS.