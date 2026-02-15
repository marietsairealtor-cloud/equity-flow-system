# GOVERNANCE CHANGE — PR006

## Change
Add CI job **foundation-invariants** and script entrypoint 
pm run foundation:invariants.

## Why this gate exists
Establish a deterministic framework to enforce **Foundation Invariants Suite** once the foundation DB surface/schema exists (tenant isolation, role enforcement, entitlement compilation, activity log write path, cross-tenant negatives).

## Why BLOCKED mode exits 0
When the required foundation schema/surface is missing, the runner prints BLOCKED_NO_FOUNDATION_SURFACE, emits FOUNDATION_INVARIANTS_BLOCKED=1, and exits **0** to avoid deadlocking merge while enforcement is not yet possible.

## Safety / Impact
No policy bypass. Enforcement is deferred until schema exists; until then the job is non-blocking by design. Once wired into required checks via truth-sync, the job name remains string-exact and stable.
