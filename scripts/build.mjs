import fs from "node:fs";
import { spawnSync } from "node:child_process";

function run(cmd, args) {
  const r = spawnSync(cmd, args, { stdio: "inherit", shell: process.platform === "win32" });
  process.exit(r.status ?? 1);
}

if (fs.existsSync("tsconfig.json")) {
  console.log("build: tsc --noEmit (WeWeb/Supabase repo)");
  run("npx", ["tsc", "-p", "tsconfig.json", "--noEmit"]);
} else {
  console.log("build: no-op (no Next.js; no tsconfig.json)");
  process.exit(0);
}