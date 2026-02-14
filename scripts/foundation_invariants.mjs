import fs from "node:fs";
import path from "node:path";

function listSql(dir){
  try{
    return fs.readdirSync(dir, { withFileTypes: true })
      .filter(d => d.isFile() && d.name.toLowerCase().endsWith(".sql"))
      .map(d => path.join(dir, d.name))
      .sort();
  }catch(_){ return []; }
}

const migDir = path.join("supabase","foundation","migrations");
const sql = listSql(migDir);

// Heuristic surface detection (non-improvised): at least one foundation migration exists.
// When the real foundation surface exists, migrations will be present and tests can run.
const hasSurface = sql.length > 0;

if (!hasSurface){
  console.log("BLOCKED_NO_FOUNDATION_SURFACE");
  console.log("FOUNDATION_INVARIANTS_BLOCKED=1");
  process.exit(0);
}

// Future-ready hook: once DB lane exists, replace this section with real invariant execution.
// For now, enforce deterministic structure presence.
const invariantDir = path.join("supabase","foundation","invariants");
const required = [
  "01_tenant_isolation.stub.sql",
  "02_role_enforcement.stub.sql",
  "03_entitlement_truth_compiles.stub.sql",
  "04_activity_log_write_path.stub.sql",
  "05_cross_tenant_negative.stub.sql"
];

let ok = true;
for (const f of required){
  const p = path.join(invariantDir, f);
  if (!fs.existsSync(p)){
    console.error("MISSING_INVARIANT_STUB:", p);
    ok = false;
  }
}
if (!ok) process.exit(1);

console.log("FOUNDATION_INVARIANTS_PRESENT_BUT_DB_RUNNER_NOT_YET_ENABLED");
process.exit(0);