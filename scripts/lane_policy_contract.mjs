import fs from "node:fs";
const lane=JSON.parse(fs.readFileSync("docs/truth/lane_policy.json","utf8"));
const req=JSON.parse(fs.readFileSync("docs/truth/required_checks.json","utf8")).checks.map(x=>x.name);
const die=(m)=>{console.error("LANE_POLICY_CONTRACT FAIL:",m);process.exit(1);};
if(lane.version!==1||!Array.isArray(lane.lanes)||!lane.lanes.length) die("invalid root/version/lanes");
const seen=new Set();
for(const L of lane.lanes){
  if(!L.lane||typeof L.lane!=="string") die("lane missing string");
  if(seen.has(L.lane)) die("duplicate lane: "+L.lane); seen.add(L.lane);
  for(const k of ["include_globs","exclude_globs","required_checks"]) if(!Array.isArray(L[k])) die(`${L.lane}.${k} must be array`);
  for(const g of [...L.include_globs,...L.exclude_globs]) if(typeof g!=="string"||!g.trim()) die(`${L.lane} glob must be non-empty string`);
  for(const c of L.required_checks){ if(typeof c!=="string"||!req.includes(c)) die(`${L.lane} unknown check: ${c}`); }
}
console.log("LANE_POLICY_CONTRACT PASS");