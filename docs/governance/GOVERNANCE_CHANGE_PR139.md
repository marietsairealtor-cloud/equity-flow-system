# Governance Change PR139 
10.8.3D Design Correctness Remediation

## What changed
This PR implements Build Route item 10.8.3D to resolve audit finding 10.8.3C-F01. It amends the historical Definition of Done for item 6.7 (Share-link surface) in BUILD_ROUTE_V2.4.md to align with the security posture established in items 8.9 and 9.4. Specifically, it replaces the requirement to return TOKEN_EXPIRED with the requirement to return NOT_FOUND for expired tokens to prevent existence leaks.

## Why safe
This change is safe because it is a documentation-only alignment that harmonizes the Build Route with the current, superior security implementation already active in the database. The actual code behavior was previously hardened and verified; this PR merely ensures the repository's authoritative "System Laws" accurately reflect the intended and tested state of the capability-token security chain.

## Risk
The risk is negligible as no functional logic or database schema is being modified. The primary risk of NOT performing this change was maintaining a technical contradiction in the repository's history where a legacy DoD requirement was superseded by a security hardening without formal documentation closure. This alignment restores the integrity of the audit trail.

## Rollback
Rollback is performed by reverting the documentation changes to BUILD_ROUTE_V2.4.md and the associated proof log. No database or application state needs to be reverted as the current implementation already follows the NOT_FOUND pattern. Reverting would return the system to a state of documented version-skew.