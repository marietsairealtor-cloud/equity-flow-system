import { spawnSync } from "node:child_process";

if (process.env.CI) process.exit(0);

// Run husky if available; never fail installs just because hooks can't install.
const r = spawnSync("husky", { stdio: "inherit", shell: true });
process.exit(r.status ?? 0);