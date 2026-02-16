import fs from "node:fs";
import { execFileSync } from "node:child_process";

function sh(args){
  return execFileSync(args[0], args.slice(1), { encoding:"utf8", stdio:["ignore","pipe","pipe"] }).trim();
}

function readJson(p){
  const raw = fs.readFileSync(p,"utf8");
  return JSON.parse(raw.charCodeAt(0)===0xFEFF ? raw.slice(1) : raw);
}

const policy = readJson("docs/truth/waiver_policy.json");
const DAYS = Number(policy.window_days);
const MAX = Number(policy.max_waivers_in_window);

if (!Number.isFinite(DAYS) || !Number.isFinite(MAX)){
  console.error("waiver-rate-limit FAIL: invalid waiver_policy.json");
  process.exit(1);
}

let log="";
try{
  log = sh(["git","log",`--since=${DAYS}.days`,`--name-only`,`--pretty=format:--%H`,"--","docs/waivers"]);
}catch{
  log="";
}

const lines = log.split(/\r?\n/).map(l=>l.trim()).filter(Boolean);

const waivers = new Set();
for (const l of lines){
  if (!l.startsWith("docs/waivers/")) continue;
  if (!/^docs\/waivers\/WAIVER_PR\d+\.md$/.test(l)) continue;
  waivers.add(l);
}

const count = waivers.size;

console.log("=== waiver-rate-limit ===");
console.log("WINDOW_DAYS=", DAYS);
console.log("MAX_WAIVERS_IN_WINDOW=", MAX);
console.log("WAIVERS_IN_WINDOW=", count);
if (count>0){
  console.log("OFFENDING_WAIVERS=");
  [...waivers].sort().forEach(f=>console.log(" -",f));
}

if (count>MAX){
  console.error("RESULT=FAIL");
  console.error(`HARD_FAIL: ${count} waivers in last ${DAYS} days (max ${MAX})`);
  process.exit(1);
}

console.log("RESULT=PASS");
process.exit(0);