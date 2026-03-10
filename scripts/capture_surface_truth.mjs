// scripts/capture_surface_truth.mjs
// 9.1: Captures PostgREST-exposed surface deterministically.
// Uses authenticated token for full RPC surface, anon for anon_exposed.
// Outputs a canonicalized surface truth JSON to docs/truth/surface_truth.json
import fs from "node:fs";
import { createRequire } from "module";
const require = createRequire(import.meta.url);

const API_URL = "http://127.0.0.1:54321";
const ANON_KEY = process.env.SUPABASE_ANON_KEY || process.env.ANON_KEY || "";
const JWT_SECRET = process.env.JWT_SECRET || "super-secret-jwt-token-with-at-least-32-characters-long";

let AUTH_TOKEN = ANON_KEY;
let ANON_TOKEN = ANON_KEY;
try {
  const jwt = require("jsonwebtoken");
  AUTH_TOKEN = jwt.sign(
    { role: "authenticated", iss: "supabase", aud: "authenticated" },
    JWT_SECRET,
    { expiresIn: "1h" }
  );
  ANON_TOKEN = jwt.sign(
    { role: "anon", iss: "supabase", aud: "authenticated" },
    JWT_SECRET,
    { expiresIn: "1h" }
  );
} catch (_) { AUTH_TOKEN = ANON_KEY; ANON_TOKEN = ANON_KEY; }

async function fetchSurfaceAs(token) {
  const headers = { "apikey": token, "Authorization": `Bearer ${token}` };
  const res = await fetch(`${API_URL}/rest/v1/`, { headers });
  if (!res.ok) throw new Error(`PostgREST responded ${res.status}`);
  return res.json();
}

async function main() {
  console.log("# capture_surface_truth.mjs");

  // Full surface via authenticated token
  const authSpec = await fetchSurfaceAs(AUTH_TOKEN);
  const authPaths = Object.keys(authSpec.paths || {}).sort();
  const rpc = authPaths.filter(p => p.startsWith("/rpc/")).map(p => p.replace("/rpc/", "")).sort();
  const tables = authPaths.filter(p => !p.startsWith("/rpc/") && p !== "/").sort().map(p => p.replace(/^\//, ""));

  // Anon surface via anon token
  const anonSpec = await fetchSurfaceAs(ANON_TOKEN);
  const anonPaths = Object.keys(anonSpec.paths || {}).sort();
  const anon_exposed = anonPaths.filter(p => p !== "/").sort();

  const surface = {
    version: 1,
    captured_at: new Date().toISOString(),
    rpc,
    tables,
    anon_exposed
  };

  if (!Array.isArray(surface.rpc)) throw new Error("rpc must be array");
  if (!Array.isArray(surface.tables)) throw new Error("tables must be array");
  if (!Array.isArray(surface.anon_exposed)) throw new Error("anon_exposed must be array");

  const out = JSON.stringify(surface, null, 2);
  fs.writeFileSync("docs/truth/surface_truth.json", out + "\n", { encoding: "utf8" });
  console.log("# Wrote docs/truth/surface_truth.json");
  console.log(`# RPCs (authenticated): ${rpc.join(", ")}`);
  console.log(`# Tables: ${tables.length > 0 ? tables.join(", ") : "(none)"}`);
  console.log(`# Anon exposed: ${anon_exposed.length} paths`);
  console.log("# DONE");
}
main().catch(e => { console.error(e); process.exit(1); });

