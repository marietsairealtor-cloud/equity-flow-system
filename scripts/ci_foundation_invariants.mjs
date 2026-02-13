import { execSync } from "node:child_process";
execSync("node scripts/foundation/run_foundation_invariants.mjs", { stdio: "inherit" });
