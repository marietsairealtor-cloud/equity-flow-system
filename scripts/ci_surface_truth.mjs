// scripts/ci_surface_truth.mjs
// 9.1: CI gate — verifies PostgREST surface matches captured surface_truth.json
// Fails if surface has grown or shrunk unexpectedly.

import fs from "node:fs";

const API_URL = "http://127.0.0.1:54321";
const ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiYXVkIjoiYXV0aGVudGljYXRlZCIsImV4cCI6MTc3MjkzNTYwMH0.placeholder";
const TRUTH_PATH = "docs/truth/surface_truth.json";

function die(msg) {
  console.error(`ci_surface_truth: FAIL - ${msg}`);
  process.exit(1);
}

async function fetchSurface() {
  const res = await fetch(`${API_URL}/rest/v1/`, {
    headers: { "apikey": ANON_KEY }
  });
  if (!res.ok) throw new Error(`PostgREST responded ${res.status}`);
  return res.json();
}

async function main() {
  console.log("=== ci_surface_truth ===");

  if (!fs.existsSync(TRUTH_PATH)) die(`${TRUTH_PATH} not found - run capture_surface_truth.mjs first`);
  const truth = JSON.parse(fs.readFileSync(TRUTH_PATH, "utf8"));

  const spec = await fetchSurface();
  const paths = Object.keys(spec.paths || {}).sort();
  const rpc = paths.filter(p => p.startsWith("/rpc/")).map(p => p.replace("/rpc/", "")).sort();
  const tables = paths.filter(p => !p.startsWith("/rpc/") && p !== "/").sort().map(p => p.replace(/^\//, ""));

  let failed = false;

  // Check RPCs
  const missingRpc = truth.rpc.filter(r => !rpc.includes(r));
  const addedRpc = rpc.filter(r => !truth.rpc.includes(r));
  if (missingRpc.length > 0) {
    console.error(`  REMOVED RPCs (not in surface): ${missingRpc.join(", ")}`);
    failed = true;
  }
  if (addedRpc.length > 0) {
    console.error(`  ADDED RPCs (not in truth): ${addedRpc.join(", ")}`);
    failed = true;
  }

  // Check tables
  const missingTables = truth.tables.filter(t => !tables.includes(t));
  const addedTables = tables.filter(t => !truth.tables.includes(t));
  if (missingTables.length > 0) {
    console.error(`  REMOVED tables (not in surface): ${missingTables.join(", ")}`);
    failed = true;
  }
  if (addedTables.length > 0) {
    console.error(`  ADDED tables (not in truth): ${addedTables.join(", ")}`);
    failed = true;
  }

  if (failed) die("surface drift detected - update docs/truth/surface_truth.json via capture_surface_truth.mjs");

  console.log(`  RPCs: ${rpc.join(", ")}`);
  console.log(`  Tables: ${tables.length > 0 ? tables.join(", ") : "(none)"}`);
  console.log("ci_surface_truth: PASS");
}

main().catch(e => { console.error(e); process.exit(1); });
