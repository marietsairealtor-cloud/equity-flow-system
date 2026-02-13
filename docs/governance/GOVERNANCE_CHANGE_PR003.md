# Governance Change Justification — PR003

- Change: add CI path filter coverage for supabase/foundation/** and products/**; enforce repo layer boundary (no cross-write); move supabase/migrations under supabase/foundation/.
- Reason: implement Build Route 2.16.5B Repo Layout Separation with deterministic governance triggers.
- Risk: medium (path moves + CI wiring drift); mitigations: truth sync, governance guard, proof log.
