# GOVERNANCE CHANGE — Build Route 10.12D2 static intake embed + Storage cleanup

UTC: 20260510T230000Z

## What changed

- **`apps/embed/seller.html`**, **`apps/embed/buyer.html`**, **`apps/embed/birddog.html`** — self-contained static intake forms; **`submit_form_v1`** only; publishable Supabase key in HTML per Build Route **10.12D2** QA ruling.
- **`apps/embed/CNAME`** — custom Pages hostname **`forms.equityflowsystems.com`** (DNS + Pages settings outside repo).
- **`.github/workflows/deploy-embed.yml`** — GitHub Actions deploy of **`apps/embed/`** to Pages (avoids using **`/docs`** for governance artifacts).
- **`supabase/migrations/20260513000002_10_12D2_cleanup_intake_forms_storage.sql`** — forward cleanup of abandoned **`intake-forms`** bucket / **`loader.html`** path (**`storage.allow_delete_query`** per platform guard); does not rewrite **`20260513000001`**.
- **`supabase/tests/10_12D2_cleanup_intake_forms_storage.test.sql`** — pgTAP: no **`intake-forms`** bucket, no **`intake_forms_public_read_loader`** policy, no orphan **`storage.objects`** rows for that bucket.
- **`docs/artifacts/BUILD_ROUTE_V2.4.md`** — §**10.12D2** replaced with **Static Embed Delivery** architecture, DoD, abandoned-path notes, proof filename **`10.12D2_static_intake_embed_<UTC>.log`**.
- **Removed:** **`scripts/upload_intake_forms.ps1`**, **`supabase/storage/intake-forms/**`** (non-canonical Storage loader assets).
- **`supabase/tests/10_12D2_intake_forms_storage_bucket.test.sql`** — removed (superseded by cleanup test asserting final schema state).
- **`.gitleaks.toml`** — allowlist paths for intentional public embed keys, synthetic pgTAP fixtures, narrative **DEVLOG** false positives, and documented Supabase anon JWT examples in **`scripts/capture_surface_truth.mjs`** / **`scripts/ci_surface_truth.mjs`** (**`jwt`** rule).
- **`.github/workflows/secrets-scan.yml`** — pass **`--config .gitleaks.toml`** to **`gitleaks detect`**.
- **`docs/truth/qa_claim.json`** — active item **`10.12D2`**.
- **`docs/truth/qa_scope_map.json`** — **`10.12D2`** title + proof pattern **`^docs/proofs/10\.12D2_static_intake_embed_`**.
- **`scripts/ci_robot_owned_guard.ps1`** — canonical proof log allowlist for **10.12D2**.

## Alignment

- **Build Route `10.12D2`** (merge-blocking). Prerequisites **`10.12D1`**, **`10.12C7`** per §10.12D2.
- **Phase 1** (SOP): migrations, tests, governance file, **`qa_claim`**, **`qa_scope_map`**, robot guard; **`.gitleaks.toml`** + CI wiring for **secrets-scan**. **Phase 2+**: **`npm run handoff`**, **`handoff_latest.txt`**, **`generated/schema.sql`**, proof finalize (not in this change set unless run separately).

## Why safe

- No new RPC or tenant write surface; public path remains existing **`submit_form_v1`** contract. Storage cleanup removes superseded bucket/policy only. Publishable key exposure is explicit product decision documented in Build Route.

## Risk

- Low. Embed HTML and Pages deploy are static; cleanup migration is idempotent-safe with **`DROP POLICY IF EXISTS`** and guarded **`DELETE`**.

## Rollback

- Revert **10.12D2** branch commits (embeds, workflow, migration **00002**, tests, gitleaks/guard/qa truth); re-apply **`20260513000001`** bucket manually if a environment still relied on Storage loader (non-canonical).
