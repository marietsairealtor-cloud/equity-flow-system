## What changed
Added Build Route item 10.8.7D (Accept Invite Tenant Context Sync) to docs/artifacts/BUILD_ROUTE_V2.4.md. No implementation changes in this PR - governance record only. 10.8.7D modifies accept_invite_v1 to set user_profiles.current_tenant_id after invite acceptance, completing the tenancy contract established in 10.8.7C.

## Why safe
Additive governance change only. New Build Route item documents a behavioral parity fix to accept_invite_v1. No scripts, migrations, tests, or truth files modified.

## Risk
Low. Build Route addition only. No enforcement rules changed.

## Rollback
Revert PR. Restores prior Build Route state without 10.8.7D.