# Governance Change — PR131

## What changed

Build Route v2.4 amended: item 10.8.3 (Reminder Engine) DoD rewritten. Two blockers identified and resolved before implementation began.

Blocker 1 — pg_cron removed. The original DoD required a pg_cron job for overdue reminder detection. pg_cron is a Supabase dashboard extension toggle, not a migration — it exists outside the governed deployment path with no CI gate, no proof artifact, and no migration replay coverage. Replaced with `list_reminders_v1` polling RPC that computes overdue status at read time (`reminder_date < now() AND completed_at IS NULL`). Same detection logic, fully governed surface.

Blocker 2 — Auto-creation on stage transition deferred to 10.11. The original DoD required "reminder auto-created on Offer Sent." `update_deal_v1` has no stage transition enforcement yet. Stage transition logic belongs in 10.11 (Acquisition Dashboard + Auto-Advance), which already owns auto-advance in its DoD. 10.8.3 builds the engine (table + RPCs). 10.11 wires the trigger.

Three RPCs added to DoD: `list_reminders_v1`, `create_reminder_v1`, `complete_reminder_v1`. All authenticated, SECURITY DEFINER, fixed search_path, tenant-derived from JWT. Full truth file registration included.

## Why safe

No merged items affected. No gate names changed. No existing RPCs modified. The rewrite narrows scope (removes external dependency, defers cross-surface wiring) and adds explicit RPC contracts that did not exist in the original DoD. All three RPCs follow the identical pattern as every other tenant-scoped SECURITY DEFINER RPC in the system. Alignment verified against GUARDRAILS §3/§5/§11–15, CONTRACTS §2/§7/§8/§9/§17, WEWEB_ARCHITECTURE §11.5/§12.1, and SOP §2.

## Risk

Low. Specification amendment only — no code, no migrations, no schema changes in this PR. Risk is limited to incorrect DoD specification. Mitigated by explicit RPC signatures and pgTAP test expectations in the DoD.

## Rollback

Revert this PR. 10.8.3 reverts to original DoD with pg_cron and auto-creation requirements. Both blockers return. No schema, code, or truth file changes to unwind.