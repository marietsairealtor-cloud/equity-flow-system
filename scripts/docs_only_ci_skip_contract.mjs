import fs from "node:fs";
import path from "node:path";

function readText(p){
  let s = fs.readFileSync(p,"utf8");
  if (s.charCodeAt(0) === 0xFEFF) s = s.slice(1);
  return s;
}
function readJson(p){ return JSON.parse(readText(p)); }

function workflowName(lines, fallback){
  for (const ln of lines){
    const m = ln.match(/^name:\s*(.+?)\s*$/);
    if (m) return m[1].trim().replace(/^["']|["']$/g,"");
  }
  return fallback;
}

function parseJobsBlock(lines){
  let inJobs=false;
  let current=null;
  const jobs=[]; // {id, display, startLine, endLine}
  const jobStartIdx=new Map();

  for (let i=0;i<lines.length;i++){
    const ln=lines[i];

    if (!inJobs){
      if (/^jobs:\s*$/.test(ln)) inJobs=true;
      continue;
    }
    // next top-level key ends jobs
    if (/^[A-Za-z0-9_-]+:\s*$/.test(ln) && !/^jobs:\s*$/.test(ln)) break;

    const jid=ln.match(/^\s{2}([A-Za-z0-9_-]+):\s*$/);
    if (jid){
      // close previous
      if (current){
        current.endLine = i-1;
        jobs.push(current);
      }
      current={id: jid[1], display: jid[1], startLine: i, endLine: lines.length-1};
      jobStartIdx.set(current.id,i);
      continue;
    }
    if (current){
      const jname=ln.match(/^\s{4}name:\s*(.+?)\s*$/);
      if (jname){
        const dn=jname[1].trim().replace(/^["']|["']$/g,"");
        if (dn) current.display=dn;
      }
    }
  }
  if (current){ jobs.push(current); }
  return jobs;
}

function jobBlockText(lines, job){
  return lines.slice(job.startLine, job.endLine+1).join("\n") + "\n";
}

const req = readJson("docs/truth/required_checks.json");
const requiredNames = (req.checks||[]).map(c=>String(c.name||"").trim()).filter(Boolean);

const wfDir=".github/workflows";
const wfFiles = fs.existsSync(wfDir) ? fs.readdirSync(wfDir).filter(f=>/\.ya?ml$/i.test(f)).map(f=>path.join(wfDir,f)) : [];

let ok=true;
function pass(msg){ console.log("PASS:", msg); }
function fail(msg){ console.log("FAIL:", msg); ok=false; }

const docsSkipIfRe = /if:\s*needs\.changes\.outputs\.docs_only\s*!=\s*'true'/i;

let discovered = new Map(); // checkName -> {file, jobId, block}
let allChecks=[];

for (const f of wfFiles){
  const lines = readText(f).split(/\r?\n/);
  const wf = workflowName(lines, path.basename(f));
  const jobs = parseJobsBlock(lines);
  for (const j of jobs){
    const checkName = `${wf} / ${j.display}`;
    const block = jobBlockText(lines, j);
    allChecks.push(checkName);
    if (!discovered.has(checkName)){
      discovered.set(checkName, {file:f, jobId:j.id, block});
    }
  }
}

allChecks = Array.from(new Set(allChecks)).sort();

console.log("=== docs-only-ci-skip contract (truth-driven) ===");
console.log("WORKFLOWS:", wfFiles.length);
console.log("DISCOVERED_CHECKS:");
for (const cn of allChecks) console.log(" -", cn);
console.log("REQUIRED_CHECKS (truth):");
for (const rn of requiredNames) console.log(" -", rn);

// baseline: must have changes + paths-filter + docs_only output
const ciYml = readText(".github/workflows/ci.yml");
if (!/dorny\/paths-filter@v\d+/i.test(ciYml)) fail("paths-filter present");
else pass("paths-filter present");
if (!/^\s{2}changes:\s*$/m.test(ciYml)) fail("changes job present");
else pass("changes job present");
if (!/docs_only:\s*\${{\s*steps\.filter\.outputs\.docs_only\s*}}/i.test(ciYml)) fail("changes outputs docs_only");
else pass("changes outputs docs_only");
if (!/filters:\s*\|[\s\S]*docs_only:\s*[\s\S]*-\s*'docs\/\*\*'/i.test(ciYml)) fail("docs_only filter includes docs/**");
else pass("docs_only filter includes docs/**");

// db-heavy must be skipped on docs_only
const dbBlock = (()=> {
  for (const v of discovered.values()){
    if (v.jobId === "db-heavy") return v.block;
  }
  return "";
})();
if (!dbBlock) fail("db-heavy job present");
else pass("db-heavy job present");
if (!docsSkipIfRe.test(dbBlock)) fail("db-heavy skipped on docs_only");
else pass("db-heavy skipped on docs_only");

// required checks must exist AND must NOT be skipped on docs_only
for (const rn of requiredNames){
  const hit = discovered.get(rn);
  if (!hit){ fail(`required check exists in workflows: ${rn}`); continue; }
  pass(`required check exists in workflows: ${rn}`);
  if (docsSkipIfRe.test(hit.block)) fail(`required check NOT skipped on docs_only: ${rn}`);
  else pass(`required check NOT skipped on docs_only: ${rn}`);
}

if (!ok){
  console.log("STATUS: FAIL (docs-only-ci-skip NOT OK)");
  process.exit(1);
}
console.log("STATUS: PASS (docs-only-ci-skip OK)");
