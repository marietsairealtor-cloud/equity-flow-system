import fs from "node:fs";
import { execSync } from "node:child_process";

const hasSurface = fs.existsSync("supabase/foundation/migrations") &&
  fs.readdirSync("supabase/foundation/migrations").some(f => f.endsWith(".sql"));

if (!hasSurface) {
  console.log("BLOCKED_NO_FOUNDATION_SURFACE: no SQL migrations under supabase/foundation/migrations; skipping invariants");
  process.exit(0);
}

execSync("node scripts/lint_bom_gate.mjs", { stdio: "inherit" });
execSync("node scripts/run_lint_sql.mjs", { stdio: "inherit" });
execSync("node scripts/lint_pgtap.mjs", { stdio: "inherit" });
console.log("foundation:invariants PASS (surface present + lint gates executed)");
