#!/usr/bin/env node
/**
 * sync_truth_registries.mjs
 * Build Route 10.8.6A — Truth Registry & Pipeline Automation
 *
 * Automatically overwrites four truth files by querying the Postgres system
 * catalog and reading the local migrations directory. Integrated into
 * npm run handoff execution sequence.
 *
 * Gracefully exits 0 if DATABASE_URL is absent (docs-only CI runs).
 */

import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";

const DB_URL = process.env.DATABASE_URL;

if (!DB_URL) {
  console.log("SYNC_TRUTH_REGISTRIES_SKIP: DATABASE_URL not set — skipping catalog sync (docs-only run).");
  process.exit(0);
}

function psql(sql) {
  const result = execSync(
    `psql "${DB_URL}" --no-psqlrc -t -A -F "|||" -c "${sql.replace(/"/g, '\\"')}"`,
    { encoding: "utf8" }
  );
  return result.trim().split("\n").filter((r) => r.trim() !== "");
}

function writeJson(filePath, data) {
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + "\n", { encoding: "utf8" });
  console.log(`SYNC: wrote ${filePath}`);
}

// ---------------------------------------------------------------------------
// DoD 1: tenant_table_selector.json
// All tables in public schema with RLS enabled
// ---------------------------------------------------------------------------
const rlsRows = psql(
  "SELECT tablename FROM pg_tables WHERE schemaname = \\'public\\' AND rowsecurity = true ORDER BY tablename;"
);
const tenantTables = rlsRows.map((r) => r.split("|||")[0].trim()).filter(Boolean);

const existingSelector = JSON.parse(fs.readFileSync("docs/truth/tenant_table_selector.json", "utf8"));
const newSelector = {
  ...existingSelector,
  tenant_owned_tables: tenantTables,
};
writeJson("docs/truth/tenant_table_selector.json", newSelector);

// ---------------------------------------------------------------------------
// DoD 2: definer_allowlist.json
// All SECURITY DEFINER functions in public schema
// Preserves existing nested structure: { allow: [...], anon_callable: [...] }
// ---------------------------------------------------------------------------
const definerRows = psql(
  "SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = \\'public\\' AND p.prosecdef = true ORDER BY p.proname;"
);
const definerNames = definerRows.map((r) => r.split("|||")[0].trim()).filter(Boolean);
const qualifiedDefiner = definerNames.map((n) => `public.${n}`);

const existingDefiner = JSON.parse(fs.readFileSync("docs/truth/definer_allowlist.json", "utf8"));
const newDefiner = {
  ...existingDefiner,
  allow: qualifiedDefiner,
};
writeJson("docs/truth/definer_allowlist.json", newDefiner);

// ---------------------------------------------------------------------------
// DoD 3: execute_allowlist.json
// All functions in public schema where EXECUTE is granted to authenticated or anon
// ---------------------------------------------------------------------------
const executeRows = psql(
  "SELECT DISTINCT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace JOIN information_schema.routine_privileges rp ON rp.routine_name = p.proname AND rp.routine_schema = \\'public\\' WHERE n.nspname = \\'public\\' AND rp.grantee IN (\\'authenticated\\', \\'anon\\') AND rp.privilege_type = \\'EXECUTE\\' ORDER BY p.proname;"
);
const executeNames = executeRows.map((r) => r.split("|||")[0].trim()).filter(Boolean);

const existingExecute = JSON.parse(fs.readFileSync("docs/truth/execute_allowlist.json", "utf8"));
const newExecute = {
  ...existingExecute,
  allow: executeNames,
};
writeJson("docs/truth/execute_allowlist.json", newExecute);

// ---------------------------------------------------------------------------
// DoD 4: cloud_migration_parity.json (ex-10.8.12)
// Derived from local supabase/migrations/ directory
// ---------------------------------------------------------------------------
const migrationsDir = "supabase/migrations";
const migrationFiles = fs.readdirSync(migrationsDir)
  .filter((f) => f.endsWith(".sql"))
  .sort();

const migrationCount = migrationFiles.length;
const latestFile = migrationFiles[migrationFiles.length - 1];
const latestTip = latestFile.split("_")[0];

const existingParity = JSON.parse(fs.readFileSync("docs/truth/cloud_migration_parity.json", "utf8"));
const newParity = {
  ...existingParity,
  migration_tip: latestTip,
  migration_tip_file: latestFile,
  migration_count: migrationCount,
  pinned_at: new Date().toISOString().slice(0, 10),
};
writeJson("docs/truth/cloud_migration_parity.json", newParity);

console.log("SYNC_TRUTH_REGISTRIES: complete.");