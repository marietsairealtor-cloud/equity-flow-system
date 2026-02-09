import cp from "node:child_process";

const sh = (c) => cp.execSync(c, { encoding: "utf8" }).trim();

sh("git fetch origin main --prune");

const out = sh("git rev-list --left-right --count origin/main...HEAD");
const [behind, ahead] = out.split(/\s+/).map(Number);

console.log("MAIN_MOVED_GUARD");
console.log("behind=" + behind + " ahead=" + ahead);

if (behind > 0) {
  console.error("FAIL: HEAD is not up-to-date with origin/main");
  console.error("FIX: git fetch origin && git rebase origin/main");
  process.exit(1);
}

console.log("PASS");