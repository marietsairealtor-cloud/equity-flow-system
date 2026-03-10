// scripts/capture_surface_truth.mjs
// 9.1: Captures PostgREST-exposed surface deterministically.
// Outputs a canonicalized surface truth JSON to docs/truth/surface_truth.json
// Run: node scripts/capture_surface_truth.mjs

import fs from "node:fs";

const API_URL = "http://127.0.0.1:54321";
const ANON_KEY = process.env.SUPABASE_ANON_KEY || process.env.ANON_KEY || "";

async function fetchSurface() {
  const res = await fetch(`${API_URL}/rest/v1/`, {
    headers: { "apikey": ANON_KEY }
  });
  // ANON_KEY optional for OpenAPI spec endpoint
  if (!res.ok) throw new Error(`PostgREST responded ${res.status}`);
  return res.json();
}

async function main() {
  console.log("# capture_surface_truth.mjs");
  const spec = await fetchSurface();

  const paths = Object.keys(spec.paths || {}).sort();
  const rpc = paths.filter(p => p.startsWith("/rpc/")).map(p => p.replace("/rpc/", "")).sort();
  const tables = paths.filter(p => !p.startsWith("/rpc/") && p !== "/").sort().map(p => p.replace(/^\//, ""));
  const anon_exposed = paths.filter(p => p !== "/").sort();

  const surface = {
    version: 1,
    captured_at: new Date().toISOString(),
    rpc,
    tables,
    anon_exposed
  };

  // Validate required fields
  if (!Array.isArray(surface.rpc)) throw new Error("rpc must be array");
  if (!Array.isArray(surface.tables)) throw new Error("tables must be array");
  if (!Array.isArray(surface.anon_exposed)) throw new Error("anon_exposed must be array");

  const out = JSON.stringify(surface, null, 2);
  fs.writeFileSync("docs/truth/surface_truth.json", out + "\n", { encoding: "utf8" });
  console.log("# Wrote docs/truth/surface_truth.json");
  console.log(`# RPCs: ${rpc.join(", ")}`);
  console.log(`# Tables: ${tables.length > 0 ? tables.join(", ") : "(none)"}`);
  console.log(`# Anon exposed: ${anon_exposed.length} paths`);
  console.log("# DONE");
}

main().catch(e => { console.error(e); process.exit(1); });

