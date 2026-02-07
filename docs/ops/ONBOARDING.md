# ONBOARDING — New Developer (Week 5)

Goal: a new dev can run `npm run ship` in **< 30 minutes** on a clean checkout.

---

## Prerequisites

- Git
- Node.js 20+
- Docker Desktop
- Supabase CLI (project-supported version)
- PowerShell (Windows) / bash (macOS/Linux)

---

## Setup (Clean Checkout)

1. Clone repo
2. Install deps:
   - `npm ci`
3. Start Supabase:
   - `npx supabase stop --no-backup`
   - `npx supabase start -x vector --ignore-health-check`

---

## First Proof Run

Run:
- `npm run ship`

Expected:
- all gates pass
- no schema drift
- no SECURITY DEFINER audit failures

If CI fails with SCHEMA DRIFT:
- run `npm run handoff`
- publish via PR lane with `npm run handoff:commit`

---

## Daily Work Loop (Summary)

- Create a branch per objective.
- Make changes.
- Run green loop twice.
- Commit + push + PR.
- Merge only when CI green.
- On main after merge: `npm run ship`.

---

## Troubleshooting

- If `psql` missing in your shell: use `docker exec ... psql` into the supabase_db container.
- If docker state is corrupted: use stop/start and cleanup scripts; avoid `db reset` unless explicitly doing recovery.

---
