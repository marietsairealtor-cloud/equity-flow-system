// scripts/ci_rpc_contract_registry.mjs
// Build Route 10.6: RPC Contract Registry gate.
// Verifies:
// 1. Every RPC in expected_surface.json and execute_allowlist.json exists in rpc_contract_registry.json
// 2. Every registry entry with a response_schema points to an existing file
// 3. Every registry entry has at least one documented error code OR explicit empty array with notes

import fs from "node:fs";

const REGISTRY_PATH = "docs/truth/rpc_contract_registry.json";
const SURFACE_PATH = "docs/truth/expected_surface.json";
const ALLOWLIST_PATH = "docs/truth/execute_allowlist.json";

// Internal helpers excluded from registry per CONTRACTS.md §17.
// These may appear in expected_surface.json (anon-accessible) but are
// not business RPCs and must not be in rpc_contract_registry.json.
const EXCLUDED_HELPERS = new Set(["current_tenant_id"]);

function die(msg) {
  console.error(`ci_rpc_contract_registry: FAIL - ${msg}`);
  process.exit(1);
}

async function main() {
  console.log("=== ci_rpc_contract_registry ===");

  // Load files
  if (!fs.existsSync(REGISTRY_PATH)) die(`${REGISTRY_PATH} not found`);
  if (!fs.existsSync(SURFACE_PATH)) die(`${SURFACE_PATH} not found`);
  if (!fs.existsSync(ALLOWLIST_PATH)) die(`${ALLOWLIST_PATH} not found`);

  const registry = JSON.parse(fs.readFileSync(REGISTRY_PATH, "utf8"));
  const surface = JSON.parse(fs.readFileSync(SURFACE_PATH, "utf8"));
  const allowlist = JSON.parse(fs.readFileSync(ALLOWLIST_PATH, "utf8"));

  const registryNames = new Set(registry.rpcs.map(r => r.name));
  let ok = true;

  // Check 1: every RPC in expected_surface.json is in registry
  // Exception: internal helpers listed in EXCLUDED_HELPERS are exempt per CONTRACTS.md §17
  console.log("\n--- Check 1: expected_surface.json RPCs in registry ---");
  for (const rpc of surface.rpc) {
    if (EXCLUDED_HELPERS.has(rpc)) {
      console.log(`  SKIP: ${rpc} (excluded internal helper per CONTRACTS.md §17)`);
      continue;
    }
    if (registryNames.has(rpc)) {
      console.log(`  PASS: ${rpc}`);
    } else {
      console.error(`  FAIL: ${rpc} in expected_surface.json but missing from registry`);
      ok = false;
    }
  }

  // Check 2: every RPC in execute_allowlist.json is in registry
  console.log("\n--- Check 2: execute_allowlist.json RPCs in registry ---");
  for (const rpc of allowlist.allow) {
    if (registryNames.has(rpc)) {
      console.log(`  PASS: ${rpc}`);
    } else {
      console.error(`  FAIL: ${rpc} in execute_allowlist.json but missing from registry`);
      ok = false;
    }
  }

  // Check 3: response_schema references point to existing files
  console.log("\n--- Check 3: response_schema file references ---");
  for (const entry of registry.rpcs) {
    if (entry.response_schema !== null) {
      if (fs.existsSync(entry.response_schema)) {
        console.log(`  PASS: ${entry.name} -> ${entry.response_schema}`);
      } else {
        console.error(`  FAIL: ${entry.name} response_schema points to missing file: ${entry.response_schema}`);
        ok = false;
      }
    } else {
      console.log(`  SKIP: ${entry.name} -> no response_schema`);
    }
  }

  // Check 4: every entry has error_codes array (may be empty) and notes
  console.log("\n--- Check 4: registry entry completeness ---");
  const requiredFields = ["name", "version", "build_route_owner", "input_contract", "response_schema", "error_codes", "notes"];
  for (const entry of registry.rpcs) {
    const missing = requiredFields.filter(f => !(f in entry));
    if (missing.length > 0) {
      console.error(`  FAIL: ${entry.name} missing fields: ${missing.join(", ")}`);
      ok = false;
    } else {
      console.log(`  PASS: ${entry.name}`);
    }
  }

  console.log("");
  if (!ok) {
    die("RPC contract registry validation failed — see above");
  }
  console.log(`Registry entries: ${registry.rpcs.length}`);
  console.log(`Surface RPCs checked: ${surface.rpc.length}`);
  console.log(`Allowlist RPCs checked: ${allowlist.allow.length}`);
  console.log("ci_rpc_contract_registry: PASS");
}

main().catch(e => { console.error(e); process.exit(1); });