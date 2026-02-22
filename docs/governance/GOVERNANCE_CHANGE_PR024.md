# GOVERNANCE CHANGE — Build Route 4.4 pg_default_acl Scope Clarification

## Trigger
Advisor escalation — platform constraint involving Supabase-managed role `supabase_admin`.

## Problem
Build Route v2.4 Item 4.4 requires that `pg_default_acl` be clean (private-by-default) for `anon` and `authenticated` on schema `public`.

On hosted Supabase:
- `supabase_admin` is a platform-owned superuser role.
- Its default ACL entries cannot be modified from migrations running as `postgres`.
- Default privileges in PostgreSQL apply only to objects created by the role that owns the default ACL entry.
- Our migrations create objects as `postgres`, not `supabase_admin`.

Requiring removal of `supabase_admin` default ACL entries is:
- Not achievable from tenant migration context.
- Not relevant to objects created by our migrations.

## Decision
4.4 DoD is clarified to:

1. Scope `pg_default_acl` cleanliness requirement to:
   - `postgres`
   - Any application-owned roles created by migrations

2. Explicitly exclude platform-managed roles:
   - `supabase_admin`
   - Any role matching `supabase_%`

3. Require materialization proof:
   - Confirm zero object-level privileges for `anon` or `authenticated`
   - Validate via catalog queries at merge time

## Security Property Preserved
The protected invariant is:

> No unintended privileges materialize on repo-owned schema objects.

This is enforced via object-level privilege checks, not platform internal default ACL configuration.

## Scope
Applies only to Build Route 4.4 pg_default_acl evaluation.

No changes to:
- CONTRACTS.md
- GUARDRAILS.md
- Privilege firewall policy
- RLS policy requirements

## Authority
Advisor ruling — platform boundary clarification.