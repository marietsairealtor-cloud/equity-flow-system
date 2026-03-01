# Governance Change — PR055

## Build Route Item
Lint compliance fix — dollar-dollar in test comments + lint false positive on GRANT/REVOKE EXECUTE

## What changed
Replaced literal dollar-dollar string in comment lines of two pgTAP test files (row_version_concurrency.test.sql, share_link_isolation.test.sql) with "No bare dollar-quoting." Fixed false positive in scripts/lint_sql_safety.ps1 where GRANT EXECUTE ON FUNCTION, REVOKE EXECUTE ON FUNCTION, and EXECUTE appearing in SQL comments triggered the SECURITY DEFINER dynamic SQL detector. Fix strips SQL comments before scanning and uses explicit privilege statement exemption instead of fragile lookbehinds.

## Why safe
Test file change is comment-only — zero SQL logic change. Lint script change is detection-only — strips comments before scanning (eliminating comment false positives) and explicitly exempts GRANT/REVOKE EXECUTE ON FUNCTION/PROCEDURE patterns. Dynamic SQL detection (bare EXECUTE and format()) still triggers on real violations. No migrations, RLS, privileges, or RPCs modified.

## Risk
Low. Lint detector still catches real dynamic SQL. The only relaxation is excluding legitimate privilege statements and SQL comments from the scan — both are verified non-executable contexts.

## Rollback
Revert lint script and two test comment lines. No downstream impact.
