import { spawnSync } from "node:child_process";
const isWin = process.platform === "win32";
const shell = isWin ? "powershell" : "pwsh";
const args = isWin
  ? ["-NoProfile","-ExecutionPolicy","Bypass","-File","scripts/lint_sql_safety.ps1"]
  : ["-NoProfile","-File","scripts/lint_sql_safety.ps1"];
const r = spawnSync(shell, args, { stdio: "inherit" });
process.exit(r.status ?? 1);
