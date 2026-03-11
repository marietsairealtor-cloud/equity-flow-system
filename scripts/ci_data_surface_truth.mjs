// scripts/ci_data_surface_truth.mjs
// 9.6: Verifies PostgREST data surface (schemas, tables, views) matches expected_surface.json.
// Hard-fails on any mismatch — privilege drift causing new table or view exposure fails CI.
// Allowed exception: user_profiles per CONTRACTS S12.

import fs from "node:fs";
import { execSync } from "node:child_process";

const EXPECTED_PATH = "docs/truth/expected_surface.json";
const DB_CONTAINER  = "supabase_db_equity-flow-system";

// Product schemas only — Supabase internal schemas (auth, storage, extensions etc.) are excluded.
const PRODUCT_SCHEMAS = ["public"];

function die(msg) {
  console.error(`ci_data_surface_truth: FAIL - ${msg}`);
  process.exit(1);
}

function sql(query) {
  return execSync(
    `docker exec -i ${DB_CONTAINER} psql -U postgres -d postgres -At -c "${query}"`,
    { encoding: "utf8" }
  ).trim();
}

function getExposedTables() {
  // Tables (not views) in public schema with SELECT granted to anon or authenticated.
  // Joins information_schema.tables to exclude views.
  const result = sql(
    "SELECT DISTINCT g.table_name " +
    "FROM information_schema.role_table_grants g " +
    "JOIN information_schema.tables t ON t.table_schema = g.table_schema AND t.table_name = g.table_name " +
    "WHERE g.grantee IN ('anon','authenticated') AND g.privilege_type = 'SELECT' " +
    "AND g.table_schema = 'public' AND t.table_type = 'BASE TABLE' " +
    "ORDER BY g.table_name;"
  );
  return result.split("\n").filter(Boolean).sort();
}

function getExposedViews() {
  // Views in public schema with SELECT granted to anon or authenticated.
  const result = sql(
    "SELECT DISTINCT g.table_name " +
    "FROM information_schema.role_table_grants g " +
    "JOIN information_schema.tables t ON t.table_schema = g.table_schema AND t.table_name = g.table_name " +
    "WHERE g.grantee IN ('anon','authenticated') AND g.privilege_type = 'SELECT' " +
    "AND g.table_schema = 'public' AND t.table_type = 'VIEW' " +
    "ORDER BY g.table_name;"
  );
  return result.split("\n").filter(Boolean).sort();
}

function getExposedProductSchemas() {
  // Only check product schemas — Supabase internal schemas are excluded.
  // Returns which product schemas have USAGE granted to anon or authenticated.
  const schemaList = PRODUCT_SCHEMAS.map(s => `'${s}'`).join(",");
  const result = sql(
    `SELECT DISTINCT nspname FROM pg_namespace n ` +
    `JOIN pg_roles r ON has_schema_privilege(r.rolname, n.nspname, 'USAGE') ` +
    `WHERE r.rolname IN ('anon','authenticated') AND nspname IN (${schemaList}) ` +
    `ORDER BY nspname;`
  );
  return result.split("\n").filter(Boolean).sort();
}

function arraysEqual(a, b) {
  if (a.length !== b.length) return false;
  return a.every((v, i) => v === b[i]);
}

async function main() {
  console.log("=== ci_data_surface_truth ===");

  if (!fs.existsSync(EXPECTED_PATH)) die(`${EXPECTED_PATH} not found`);
  const expected = JSON.parse(fs.readFileSync(EXPECTED_PATH, "utf8"));

  if (!expected.schemas_exposed) die("expected_surface.json missing schemas_exposed field");
  if (!expected.tables_exposed)  die("expected_surface.json missing tables_exposed field");
  if (!expected.views_exposed)   die("expected_surface.json missing views_exposed field");

  const expectedSchemas = [...expected.schemas_exposed].sort();
  const expectedTables  = [...expected.tables_exposed].sort();
  const expectedViews   = [...expected.views_exposed].sort();

  let failed = false;

  // Check 1: Product schemas exposed
  console.log("Check 1: exposed product schemas vs expected_surface...");
  const actualSchemas = getExposedProductSchemas();
  if (!arraysEqual(actualSchemas, expectedSchemas)) {
    console.error(`  FAIL: product schemas mismatch`);
    console.error(`  expected: ${expectedSchemas.join(", ")}`);
    console.error(`  actual:   ${actualSchemas.join(", ")}`);
    failed = true;
  } else {
    console.log(`  PASS: product schemas match (${actualSchemas.join(", ")})`);
  }

  // Check 2: Tables exposed
  console.log("Check 2: exposed tables vs expected_surface...");
  const actualTables = getExposedTables();
  if (!arraysEqual(actualTables, expectedTables)) {
    console.error(`  FAIL: tables mismatch — privilege drift detected`);
    console.error(`  expected: [${expectedTables.join(", ")}]`);
    console.error(`  actual:   [${actualTables.join(", ")}]`);
    const unexpected = actualTables.filter(t => !expectedTables.includes(t));
    if (unexpected.length > 0) {
      console.error(`  unexpected exposure: ${unexpected.join(", ")}`);
    }
    failed = true;
  } else {
    console.log(`  PASS: tables match ([${actualTables.join(", ")}])`);
  }

  // Check 3: Views exposed
  console.log("Check 3: exposed views vs expected_surface...");
  const actualViews = getExposedViews();
  if (!arraysEqual(actualViews, expectedViews)) {
    console.error(`  FAIL: views mismatch — privilege drift detected`);
    console.error(`  expected: [${expectedViews.join(", ")}]`);
    console.error(`  actual:   [${actualViews.join(", ")}]`);
    const unexpected = actualViews.filter(v => !expectedViews.includes(v));
    if (unexpected.length > 0) {
      console.error(`  unexpected exposure: ${unexpected.join(", ")}`);
    }
    failed = true;
  } else {
    console.log(`  PASS: views match ([${actualViews.join(", ")}])`);
  }

  if (failed) die("data surface invariant violations detected");

  console.log("");
  console.log(`Schemas exposed: ${actualSchemas.join(", ")}`);
  console.log(`Tables exposed:  ${actualTables.join(", ") || "(none)"}`);
  console.log(`Views exposed:   ${actualViews.join(", ") || "(none)"}`);
  console.log("ci_data_surface_truth: PASS");
}

main().catch(e => { console.error(e); process.exit(1); });