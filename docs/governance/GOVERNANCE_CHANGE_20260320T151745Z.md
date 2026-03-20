## What changed
Added Build Route item 10.8.7A (Deal Photos Storage Bucket) to docs/artifacts/BUILD_ROUTE_V2.4.md. No implementation changes in this PR - governance record only.

## Why safe
Additive governance change only. New Build Route item documents a new storage bucket for deal photos. No scripts, migrations, tests, or truth files modified. Implementation of 10.8.7A will be gated lane-only when executed.

## Risk
Low. Build Route addition only. No enforcement rules changed.

## Rollback
Revert PR. Restores prior Build Route state without 10.8.7A.