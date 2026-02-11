import { execFileSync } from "node:child_process";

function sh(args, opts={}){
  return execFileSync(args[0], args.slice(1), { encoding:"utf8", stdio:["ignore","pipe","pipe"], ...opts }).trim();
}

function main(){
  const DAYS = 14;
  const THRESH = 1; // >1 in last 14 days => hard FAIL

  // Ensure we have history (CI should checkout with fetch-depth: 0)
  let log = "";
  try {
    log = sh(["git","log",`--since=${DAYS}.days`,`--name-only`,`--pretty=format:--%H`,"--","docs/waivers"]);
  } catch {
    // If docs/waivers doesn't exist or no history, treat as zero usage
    log = "";
  }

  const lines = log.split(/\r?\n/).map(l=>l.trim()).filter(Boolean);

  // Collect unique waiver files touched in window
  const waivers = new Set();
  for (const l of lines){
    // file paths appear as-is from git log --name-only
    if (!l.startsWith("docs/waivers/")) continue;
    if (!/^docs\/waivers\/WAIVER_PR\d+\.md$/.test(l)) continue;
    waivers.add(l);
  }

  const count = waivers.size;

  console.log("=== waiver-debt-enforcement ===");
  console.log("WINDOW_DAYS=", DAYS);
  console.log("THRESHOLD=", THRESH, "(hard fail if > THRESHOLD)");
  console.log("WAIVERS_TOUCHED=", count);
  if (count > 0){
    console.log("WAIVER_FILES=");
    [...waivers].sort().forEach(f=>console.log(" -", f));
  }

  if (count > THRESH){
    console.log("RESULT=FAIL");
    console.error(`HARD_FAIL: >${THRESH} waivers touched in last ${DAYS} days. Convert to INCIDENT or remove waivers.`);
    process.exit(1);
  }

  if (count > 0){
    console.log("RESULT=WARN");
    console.log(`WARN: ${count} waiver touched in last ${DAYS} days (<= threshold). Cleanup required soon.`);
    process.exit(0);
  }

  console.log("RESULT=PASS");
  process.exit(0);
}

main();
