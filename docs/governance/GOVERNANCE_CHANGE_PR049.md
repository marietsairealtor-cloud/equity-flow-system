# Governance Change — PR049

## What changed
Build Route 6.6 Product Core Tables. Added 5 migrations: deal_inputs, deal_outputs, calc_versions tables; update_deal_v1 RPC with optimistic concurrency; deals snapshot reference with deferrable FK and constraint trigger; create_deal_v1 v2 with circular FK handling. Updated definer_allowlist.json (3 SD functions), execute_allowlist.json (3 RPCs), tenant_table_selector.json (3 tenant-owned tables), background_context_review.json (3 triggers), write_path_registry.json (new truth file, triple-registered). Fixed definer-safety-audit prosrc multi-line parsing bug. SOP_WORKFLOW.md updated with triple-registration rule.

## Why safe
All new tables have RLS enabled with default deny. No direct grants to anon or authenticated on new tables. Access exclusively via SECURITY DEFINER RPCs with tenant binding. Optimistic concurrency via row_version. Cross-tenant triggers prevent tenant mismatch. Deferrable constraint trigger enforces snapshot invariant at commit time. All existing gates pass.

## Risk
Medium — schema changes with 5 new migrations, new RPCs, new triggers. Mitigated by pgTAP tests (row_version concurrency, tenant isolation, RLS structural audit), definer-safety-audit, anon-privilege-audit, blocked-identifiers all passing.

## Rollback
Revert the PR. Drop migrations 000012-000016 via new corrective migration. Restore prior truth files. No data loss (no production data exists in rebuild mode).
