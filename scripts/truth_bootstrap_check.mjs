import fs from "node:fs";

const required = [
  "docs/truth/required_checks.json",
  "docs/truth/lane_checks.json",
  "docs/truth/toolchain.json",
  "docs/truth/qa_requirements.json",
  "docs/truth/expected_surface.json",
  "docs/truth/execute_allowlist.json",
  "docs/truth/definer_allowlist.json",
  "docs/truth/pr_scope_rules.json",
  "docs/truth/robot_owned_paths.json",
  "docs/truth/rpc_budget.json",
  "docs/truth/blocked_identifiers.json",
  "docs/truth/tenant_table_selector.json",
  "docs/truth/privilege_truth.json",
  "docs/truth/qa_requirements.schema.json",
  "docs/truth/qa_scope_map.json",
  "docs/truth/qa_claim.json",
  "docs/truth/surface_truth.schema.json",
  "docs/truth/cloud_inventory.schema.json",
  "docs/truth/privilege_truth.schema.json",
];

let ok = true;

function readText(path) {
  let s = fs.readFileSync(path, "utf8");
  if (s.charCodeAt(0) === 0xFEFF) s = s.slice(1); // strip BOM
  return s;
}

function parseJson(path) {
  const s = readText(path);
  return JSON.parse(s);
}

function assertHas(obj, keys, label) {
  for (const k of keys) {
    if (!(k in obj)) {
      console.log(`SCHEMA_LITE_FAIL: ${label} missing key '${k}'`);
      ok = false;
      return;
    }
  }
  console.log(`SCHEMA_LITE_PASS: ${label}`);
}

console.log("=== truth-bootstrap: required paths (existence) ===");
for (const p of required) {
  const exists = fs.existsSync(p);
  console.log(`${exists ? "PASS" : "FAIL"} EXISTS ${p}`);
  if (!exists) ok = false;
}

console.log("=== truth-bootstrap: JSON parse ===");
const parsed = new Map();
for (const p of required) {
  if (!fs.existsSync(p)) continue;
  try {
    parsed.set(p, parseJson(p));
    console.log(`PASS JSON ${p}`);
  } catch (e) {
    console.log(`FAIL JSON ${p} :: ${String(e.message || e)}`);
    ok = false;
  }
}

console.log("=== truth-bootstrap: schema-lite checks (no Ajv) ===");
if (parsed.has("docs/truth/qa_claim.json")) {
  assertHas(parsed.get("docs/truth/qa_claim.json"), ["item"], "qa_claim.json");
}
if (parsed.has("docs/truth/qa_scope_map.json")) {
  assertHas(parsed.get("docs/truth/qa_scope_map.json"), ["version","items"], "qa_scope_map.json");
}
if (parsed.has("docs/truth/qa_requirements.json")) {
  assertHas(parsed.get("docs/truth/qa_requirements.json"), ["version","requirements"], "qa_requirements.json");
}
if (parsed.has("docs/truth/expected_surface.json")) {
  assertHas(parsed.get("docs/truth/expected_surface.json"), ["version","rpc","tables"], "expected_surface.json");
}
if (parsed.has("docs/truth/privilege_truth.json")) {
  assertHas(parsed.get("docs/truth/privilege_truth.json"), ["version","roles","rules"], "privilege_truth.json");
}
for (const schemaPath of [
  "docs/truth/qa_requirements.schema.json",
  "docs/truth/surface_truth.schema.json",
  "docs/truth/cloud_inventory.schema.json",
  "docs/truth/privilege_truth.schema.json",
]) {
  if (parsed.has(schemaPath)) assertHas(parsed.get(schemaPath), ["$schema","type"], schemaPath);
}

if (!ok) {
  console.log("STATUS: FAIL (truth-bootstrap NOT OK)");
  process.exit(1);
}
console.log("STATUS: PASS (truth-bootstrap OK)");
