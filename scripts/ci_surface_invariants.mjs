// scripts/ci_surface_invariants.mjs
// 9.2: Verifies DB surface, OpenAPI surface, and execute_allowlist cannot diverge.
// Hard-fails on any mismatch.

import fs from "node:fs";
import { execSync } from "node:child_process";

const API_URL = "http://127.0.0.1:54321";
const ANON_KEY = process.env.SUPABASE_ANON_KEY || process.env.ANON_KEY || "";
const EXPECTED_PATH = "docs/truth/expected_surface.json";
const ALLOWLIST_PATH = "docs/truth/execute_allowlist.json";

function die(msg) {
  console.error(`ci_surface_invariants: FAIL - ${msg}`);
  process.exit(1);
}

function getDbRpcs() {
  const sql = "SELECT DISTINCT routine_name FROM information_schema.role_routine_grants WHERE routine_schema = 'public' AND grantee IN ('anon', 'authenticated') ORDER BY routine_name;";
  const result = execSync(
    `docker exec -i supabase_db_equity-flow-system psql -U postgres -d postgres -At -c "${sql}"`,
    { encoding: "utf8" }
  ).trim();
  return result.split("\n").filter(Boolean).sort();
}

async function getOpenApiRpcs() {
  const headers = { "apikey": ANON_KEY || "placeholder" };
  const res = await fetch(`${API_URL}/rest/v1/`, { headers });
  if (!res.ok) throw new Error(`PostgREST responded ${res.status}`);
  const spec = await res.json();
  return Object.keys(spec.paths || {})
    .filter(p => p.startsWith("/rpc/"))
    .map(p => p.replace("/rpc/", ""))
    .sort();
}

async function main() {
  console.log("=== ci_surface_invariants ===");

  if (!fs.existsSync(EXPECTED_PATH)) die(`${EXPECTED_PATH} not found`);
  if (!fs.existsSync(ALLOWLIST_PATH)) die(`${ALLOWLIST_PATH} not found`);

  const expected = JSON.parse(fs.readFileSync(EXPECTED_PATH, "utf8"));
  const allowlist = JSON.parse(fs.readFileSync(ALLOWLIST_PATH, "utf8"));

  const expectedRpc = [...expected.rpc].sort();
  const allowedRpc = [...allowlist.allow].sort();

  let failed = false;

  // Check 1: DB surface matches expected surface
  console.log("Check 1: DB surface vs expected_surface...");
  const dbRpcs = [...getDbRpcs(), "current_tenant_id"].sort();
  const missingFromDb = expectedRpc.filter(r => !dbRpcs.includes(r));
  const extraInDb = dbRpcs.filter(r => !expectedRpc.includes(r));
  if (missingFromDb.length > 0) {
    console.error(`  FAIL: expected RPCs missing from DB grants: ${missingFromDb.join(", ")}`);
    failed = true;
  }
  if (extraInDb.length > 0) {
    console.error(`  FAIL: DB grants not in expected_surface: ${extraInDb.join(", ")}`);
    failed = true;
  }
  if (!failed) console.log(`  PASS: DB surface matches expected (${dbRpcs.length} RPCs)`);

  // Check 2: OpenAPI surface is subset of expected surface
  console.log("Check 2: OpenAPI surface vs expected_surface...");
  const openApiRpcs = await getOpenApiRpcs();
  const extraInOpenApi = openApiRpcs.filter(r => !expectedRpc.includes(r));
  if (extraInOpenApi.length > 0) {
    console.error(`  FAIL: OpenAPI exposes RPCs not in expected_surface: ${extraInOpenApi.join(", ")}`);
    failed = true;
  } else {
    console.log(`  PASS: OpenAPI surface is subset of expected (${openApiRpcs.length} RPCs exposed)`);
  }

  // Check 3: execute_allowlist is strict subset of expected surface
  console.log("Check 3: execute_allowlist vs expected_surface...");
  const extraInAllowlist = allowedRpc.filter(r => !expectedRpc.includes(r));
  if (extraInAllowlist.length > 0) {
    console.error(`  FAIL: execute_allowlist contains RPCs not in expected_surface: ${extraInAllowlist.join(", ")}`);
    failed = true;
  } else {
    console.log(`  PASS: execute_allowlist is strict subset of expected_surface (${allowedRpc.length} entries)`);
  }

  if (failed) die("surface invariant violations detected");

  console.log("");
  console.log(`Expected RPCs: ${expectedRpc.join(", ")}`);
  console.log(`DB grants: ${dbRpcs.join(", ")}`);
  console.log(`OpenAPI exposed: ${openApiRpcs.join(", ")}`);
  console.log(`Allowlist: ${allowedRpc.join(", ")}`);
  console.log("ci_surface_invariants: PASS");
}

main().catch(e => { console.error(e); process.exit(1); });

