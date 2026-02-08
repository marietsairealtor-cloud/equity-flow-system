import fs from "node:fs";

const mustExist = [
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
  "docs/truth/surface_truth.schema.json",
  "docs/truth/cloud_inventory.schema.json",
  "docs/truth/privilege_truth.schema.json",
];

let ok = true;

function readText(path) {
  let s = fs.readFileSync(path, "utf8");
  if (s.charCodeAt(0) === 0xFEFF) s = s.slice(1); // strip UTF-8 BOM
  return s;
}

function must(path) {
  if (!fs.existsSync(path)) { console.error("MISSING:", path); ok = false; return; }
  const s = readText(path);
  try { JSON.parse(s); }
  catch (e) { console.error("INVALID_JSON:", path, String(e.message||e)); ok = false; }
}

console.log("=== truth-bootstrap: existence + JSON parse ===");
for (const p of mustExist) must(p);

if (!ok) process.exit(1);
console.log("OK: all truth files exist and parse as JSON");
