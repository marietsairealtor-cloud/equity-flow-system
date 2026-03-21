## What changed
Added Build Route item 10.8.7B (Tenant Invites + Accept Invite RPC) to docs/artifacts/BUILD_ROUTE_V2.4.md. No implementation changes in this PR - governance record only. 10.8.7B is a prerequisite for 10.8.8 invite acceptance flow.

## Why safe
Additive governance change only. New Build Route item documents tenant_invites table and accept_invite_v1 RPC. No scripts, migrations, tests, or truth files modified.

## Risk
Low. Build Route addition only. No enforcement rules changed.

## Rollback
Revert PR. Restores prior Build Route state without 10.8.7B.