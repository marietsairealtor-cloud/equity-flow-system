import fs from "node:fs";
import path from "node:path";

function readText(p){
  let s = fs.readFileSync(p,"utf8");
  if (s.charCodeAt(0) === 0xFEFF) s = s.slice(1);
  return s;
}
function readJson(p){ return JSON.parse(readText(p)); }

function parseWorkflow(filePath){
  const lines = readText(filePath).split(/\r?\n/);
  let wfName = null;

  // workflow name (top-level)
  for (const ln of lines){
    const m = ln.match(/^name:\s*(.+?)\s*$/);
    if (m){ wfName = m[1].trim().replace(/^["']|["']$/g,""); break; }
  }
  if (!wfName) wfName = path.basename(filePath);

  // jobs parsing (simple state machine)
  let inJobs = false;
  let currentJobId = null;
  const jobs = new Map(); // id -> displayName
  for (let i=0;i<lines.length;i++){
    const ln = lines[i];

    if (!inJobs){
      if (/^jobs:\s*$/.test(ln)) inJobs = true;
      continue;
    }

    // exit jobs on next top-level key (no indent)
    if (/^[A-Za-z0-9_-]+:\s*$/.test(ln) && !/^jobs:\s*$/.test(ln)) break;

    // job id line: two-space indent
    const jid = ln.match(/^\s{2}([A-Za-z0-9_-]+):\s*$/);
    if (jid){
      currentJobId = jid[1];
      jobs.set(currentJobId, currentJobId);
      continue;
    }

    // job display name: four-space indent under current job
    if (currentJobId){
      const jname = ln.match(/^\s{4}name:\s*(.+?)\s*$/);
      if (jname){
        const dn = jname[1].trim().replace(/^["']|["']$/g,"");
        jobs.set(currentJobId, dn || currentJobId);
      }
    }
  }

  const checkNames = [];
  for (const [id, display] of jobs.entries()){
    checkNames.push(`${wfName} / ${display}`);
  }
  return { wfName, checkNames };
}

const reqPath = "docs/truth/required_checks.json";
const lanePath = "docs/truth/lane_checks.json";

const required = readJson(reqPath);
const lane = readJson(lanePath);

const requiredNames = (required.checks||[]).map(c=>String(c.name||"").trim()).filter(Boolean);
const laneOnlyNames = new Set(
  (lane.lanes||[]).flatMap(l=>Array.isArray(l.checks)?l.checks:[]).map(s=>String(s).trim()).filter(Boolean)
);

const wfDir = ".github/workflows";
const wfFiles = fs.existsSync(wfDir)
  ? fs.readdirSync(wfDir).filter(f=>/\.ya?ml$/i.test(f)).map(f=>path.join(wfDir,f))
  : [];

let discovered = new Set();
let discoveredList = [];
for (const f of wfFiles){
  const { wfName, checkNames } = parseWorkflow(f);
  for (const cn of checkNames){
    discovered.add(cn);
    discoveredList.push(cn);
  }
}
discoveredList = Array.from(new Set(discoveredList)).sort();

let ok = true;

console.log("=== required-checks-contract ===");
console.log("WORKFLOWS:", wfFiles.length);
console.log("DISCOVERED_CHECKS:");
for (const cn of discoveredList) console.log(" -", cn);

console.log("REQUIRED_CHECKS:");
for (const rn of requiredNames) console.log(" -", rn);

console.log("=== verify: no lane-only checks in required_checks.json ===");
for (const rn of requiredNames){
  if (laneOnlyNames.has(rn)){
    console.log("FAIL LANE_ONLY_IN_REQUIRED:", rn);
    ok = false;
  }
}
if (ok) console.log("PASS lane-only excluded");

console.log("=== verify: required_checks.json matches workflow job names (string-exact) ===");
for (const rn of requiredNames){
  if (!discovered.has(rn)){
    console.log("FAIL PHANTOM_REQUIRED_CHECK:", rn);
    ok = false;
  }
}
if (ok) console.log("PASS required checks all map to workflow job names");

if (!ok){
  console.log("STATUS: FAIL (required-checks-contract NOT OK)");
  process.exit(1);
}
console.log("STATUS: PASS (required-checks-contract OK)");
