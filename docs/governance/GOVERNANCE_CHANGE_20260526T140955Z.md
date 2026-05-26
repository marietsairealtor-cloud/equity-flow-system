# Governance Change — Supabase CLI Upgrade to 2.101.0

## What changed
Updated docs/truth/toolchain.json supabase_cli expect prefix from 2.90. to 2.101. Updated package.json and package-lock.json to install supabase@2.101.0 via npm.

## Why safe
The CLI upgrade fixes a confirmed bug in 2.90.x where multi-statement migration files silently stopped execution after the first DDL statement while still recording the migration as applied. No schema, RPC, privilege, or business logic changes. Toolchain version contract updated to match new installed version.

## Risk
Low. Toolchain version bump only. All existing migrations, pgTAP tests, and CI gates verified green after upgrade. Migration runner now correctly applies all statements in multi-statement files.

## Rollback
Revert package.json and package-lock.json to supabase@2.90.x and restore toolchain.json expect prefix to 2.90. via a follow-up PR.