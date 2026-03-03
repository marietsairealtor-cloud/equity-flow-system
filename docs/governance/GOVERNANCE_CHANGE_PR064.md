# Governance Change — PR064

## Build Route Item
7.2 Build Route DoD clarification

## What changed
Reformatted and consolidated 7.2 DoD section in BUILD_ROUTE_V2.4.md. Changed "DoD additions (appended to existing 7.2 DoD)" to unified "DoD" section. Consolidated privilege_truth.json anon role requirement into single paragraph. Removed redundant phrasing about lint gate allowlist mechanism. No behavioral or policy changes — same requirements, cleaner formatting.

## Why safe
Documentation-only change to BUILD_ROUTE. No code, scripts, CI, migrations, or truth files modified. The DoD requirements are identical in substance — only formatting and wording clarity improved.

## Risk
None. No functional changes.

## Rollback
Revert BUILD_ROUTE_V2.4.md to prior version. No downstream impact.
