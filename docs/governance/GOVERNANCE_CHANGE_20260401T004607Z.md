What changed
Added /today page shell in WeWeb: summary strip (4 stat cards),
pipeline pills (6 stages), task list (3 placeholder rows with health
dot, address, context line, action button). Placeholder data only.
No live RPCs, no business logic, no direct table calls.

Why safe
WeWeb UI shell only. No schema changes, no RPC changes, no truth
file changes. No security surface affected.

Risk
None. Static placeholder layout.

Rollback
Revert WeWeb page changes via WeWeb version history.