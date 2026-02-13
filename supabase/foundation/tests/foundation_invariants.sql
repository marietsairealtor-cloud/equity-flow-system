BEGIN;
SELECT plan(5);
SELECT skip('tenant isolation', 1, 'BLOCKED_NO_FOUNDATION_SURFACE');
SELECT skip('role enforcement matrix', 1, 'BLOCKED_NO_FOUNDATION_SURFACE');
SELECT skip('entitlement truth compiles', 1, 'BLOCKED_NO_FOUNDATION_SURFACE');
SELECT skip('activity log allowlisted write path', 1, 'BLOCKED_NO_FOUNDATION_SURFACE');
SELECT skip('cross-tenant negative test (DENY)', 1, 'BLOCKED_NO_FOUNDATION_SURFACE');
SELECT * FROM finish();
ROLLBACK;
