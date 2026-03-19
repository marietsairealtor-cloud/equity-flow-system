## What changed
Added Build Route item 10.8.6A (Truth Registry and Pipeline Automation) which absorbs and supersedes item 10.8.12 (Automate Cloud Migration Parity Registry). Item 10.8.12 is marked SUPERSEDED BY 10.8.6A in the Build Route. No implementation changes in this PR - governance record only.

## Why safe
Additive governance change only. No scripts, migrations, tests, or truth files modified. 10.8.6A expands the scope of 10.8.12 to cover all four truth registries (tenant_table_selector, definer_allowlist, execute_allowlist, cloud_migration_parity) rather than just migration parity. The broader automation scope reduces manual error surface.

## Risk
Low. Build Route update only. No enforcement rules changed. Implementation of 10.8.6A will be gated merge-blocking when executed.

## Rollback
Revert PR. Restores prior Build Route state with 10.8.12 active and 10.8.6A absent.