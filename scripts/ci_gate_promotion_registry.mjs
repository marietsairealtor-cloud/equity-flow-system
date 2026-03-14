// scripts/ci_gate_promotion_registry.mjs
// Build Route 10.7: Gate Promotion Protocol.
// Verifies gate_promotion_registry.json is consistent with
// required_checks.json and ci.yml required.needs.
//
// Rules (per QA ruling 2026-03-13):
// 1. merge-blocking entry -> must exist in required_checks.json AND required.needs
// 2. lane-only entry -> must NOT exist in required_checks.json or required.needs
// 3. merge-blocking entry -> promoted_by must not be null
// Does NOT fail if foundational gates (pre-Section 10) are in required_checks.json
// but absent from registry — registry scope is Section 10 only.

import fs from "node:fs";

const REGISTRY_PATH = "docs/truth/gate_promotion_registry.json";
const REQUIRED_CHECKS_PATH = "docs/truth/required_checks.json";
const CI_WORKFLOW_PATH = ".github/workflows/ci.yml";

function die(msg) {
  console.error(`ci_gate_promotion_registry: FAIL - ${msg}`);
  process.exit(1);
}

async function main() {
  console.log("=== ci_gate_promotion_registry ===");

  if (!fs.existsSync(REGISTRY_PATH)) die(`${REGISTRY_PATH} not found`);
  if (!fs.existsSync(REQUIRED_CHECKS_PATH)) die(`${REQUIRED_CHECKS_PATH} not found`);
  if (!fs.existsSync(CI_WORKFLOW_PATH)) die(`${CI_WORKFLOW_PATH} not found`);

  const registry = JSON.parse(fs.readFileSync(REGISTRY_PATH, "utf8"));
  const requiredChecks = JSON.parse(fs.readFileSync(REQUIRED_CHECKS_PATH, "utf8"));
  const ciYml = fs.readFileSync(CI_WORKFLOW_PATH, "utf8");

  // Build sets for fast lookup
  const requiredCheckNames = new Set(
    requiredChecks.checks.map(c => c.name.replace(/^CI \/ /, ""))
  );

  // Extract required.needs from ci.yml
  const needsMatch = ciYml.match(/needs:\s*\[([^\]]+)\]/g) || [];
  const requiredNeeds = new Set();
  for (const match of needsMatch) {
    const inner = match.replace(/needs:\s*\[/, "").replace(/\]/, "");
    for (const dep of inner.split(",").map(s => s.trim())) {
      requiredNeeds.add(dep);
    }
  }

  let ok = true;

  console.log(`\nRegistry gates: ${registry.gates.length}`);
  console.log("--- Checking registry entries ---");

  for (const gate of registry.gates) {
    console.log(`\nGate: ${gate.name} (${gate.current_status})`);

    // Validate required fields
    const requiredFields = ["name", "current_status", "promotion_trigger", "build_route_owner", "promoted_by"];
    const missing = requiredFields.filter(f => !(f in gate));
    if (missing.length > 0) {
      console.error(`  FAIL: missing fields: ${missing.join(", ")}`);
      ok = false;
      continue;
    }

    if (gate.current_status === "merge-blocking") {
      // Rule 1: must be in required_checks.json
      if (requiredCheckNames.has(gate.name)) {
        console.log(`  PASS: in required_checks.json`);
      } else {
        console.error(`  FAIL: merge-blocking but missing from required_checks.json`);
        ok = false;
      }

      // Rule 1: must be in required.needs
      if (requiredNeeds.has(gate.name)) {
        console.log(`  PASS: in required.needs`);
      } else {
        console.error(`  FAIL: merge-blocking but missing from required.needs`);
        ok = false;
      }

      // Rule 3: promoted_by must not be null
      if (gate.promoted_by !== null) {
        console.log(`  PASS: promoted_by = ${gate.promoted_by}`);
      } else {
        console.error(`  FAIL: status is merge-blocking but promoted_by is null`);
        ok = false;
      }

    } else if (gate.current_status === "lane-only") {
      // Rule 2: must NOT be in required_checks.json
      if (!requiredCheckNames.has(gate.name)) {
        console.log(`  PASS: not in required_checks.json (correct for lane-only)`);
      } else {
        console.error(`  FAIL: lane-only but found in required_checks.json`);
        ok = false;
      }

      // Rule 2: must NOT be in required.needs
      if (!requiredNeeds.has(gate.name)) {
        console.log(`  PASS: not in required.needs (correct for lane-only)`);
      } else {
        console.error(`  FAIL: lane-only but found in required.needs`);
        ok = false;
      }

      // Rule 3: promoted_by must be null for lane-only
      if (gate.promoted_by === null) {
        console.log(`  PASS: promoted_by = null (correct for lane-only)`);
      } else {
        console.error(`  FAIL: status is lane-only but promoted_by is not null`);
        ok = false;
      }

    } else {
      console.error(`  FAIL: unknown status '${gate.current_status}' — must be lane-only or merge-blocking`);
      ok = false;
    }
  }

  console.log("");
  if (!ok) {
    die("Gate promotion registry validation failed — see above");
  }
  console.log("ci_gate_promotion_registry: PASS");
}

main().catch(e => { console.error(e); process.exit(1); });