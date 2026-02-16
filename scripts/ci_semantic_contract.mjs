import fs from "node:fs";
import path from "node:path";

function readText(p){
  let s = fs.readFileSync(p,"utf8");
  if (s.charCodeAt(0) === 0xFEFF) s = s.slice(1);
  return s;
}

function listWorkflows(dir=".github/workflows"){
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir)
    .filter(f=>/\.ya?ml$/i.test(f))
    .map(f=>path.join(dir,f))
    .sort();
}

function parseWorkflowJobs(filePath){
  // Minimal YAML-ish parser with job/steps state tracking (indentation-tolerant)
  const lines = readText(filePath).split(/\r?\n/);

  let wfName = path.basename(filePath);
  for (const ln of lines){
    const m = ln.match(/^name:\s*(.+?)\s*$/);
    if (m){ wfName = m[1].trim().replace(/^["']|["']$/g,""); break; }
  }

  const jobs = new Map(); // id -> {id, display, runs:[]}
  let inJobs = false;
  let current = null;
  let inSteps = false;

  const indentOf = (s)=>((s.match(/^(\s+)/)||["",""])[1].length);

  for (let i=0;i<lines.length;i++){
    const ln = lines[i];

    // enter jobs:
    if (!inJobs){
      if (/^jobs:\s*$/.test(ln)) inJobs = true;
      continue;
    }

    // leave jobs: when a new top-level key starts (no leading spaces) and it's not jobs:
    if (/^[A-Za-z0-9_-]+:\s*$/.test(ln) && !/^jobs:\s*$/.test(ln)) break;

    // job start (2-space indent)
    const jid = ln.match(/^\s{2}([A-Za-z0-9_-]+):\s*$/);
    if (jid){
      current = jid[1];
      inSteps = false;
      jobs.set(current,{ id: current, display: current, runs: [] });
      continue;
    }
    if (!current) continue;

    // if indentation drops below job-body (4 spaces), we're not in steps anymore
    const ind = indentOf(ln);
    if (inSteps && ln.trim() !== "" && ind < 4) inSteps = false;

    // display name
    const jname = ln.match(/^\s{4}name:\s*(.+?)\s*$/);
    if (jname){
      const dn = jname[1].trim().replace(/^["']|["']$/g,"");
      jobs.get(current).display = dn || current;
      continue;
    }

    // enter steps:
    if (/^\s{4}steps:\s*$/.test(ln)){
      inSteps = true;
      continue;
    }
    if (!inSteps) continue;

    // run: single-line (covers "- run:" and "run:" inside a step)
    const runLine = ln.match(/^\s{6,}(?:-\s*)?run:\s*(.+?)\s*$/);
    if (runLine && runLine[1] !== "|"){
      jobs.get(current).runs.push(runLine[1]);
      continue;
    }

    // run: | block (covers "- run: |" and "run: |")
    const runBlock = ln.match(/^\s{6,}(?:-\s*)?run:\s*\|\s*$/);
    if (runBlock){
      const baseIndent = indentOf(ln);
      let j = i + 1;
      const block = [];
      for (; j < lines.length; j++){
        const l2 = lines[j];
        if (/^\s*$/.test(l2)){ block.push(""); continue; }
        const ind2 = indentOf(l2);
        if (ind2 <= baseIndent) break;
        block.push(l2.trimEnd());
      }
      jobs.get(current).runs.push(block.join("\n").trim());
      i = j - 1;
      continue;
    }
  }

  return { wfName, jobs };
}

function loadRequiredChecks(){
  const p="docs/truth/required_checks.json";
  const j=JSON.parse(readText(p));
  return (j.checks||[]).map(c=>String(c.name||"").trim()).filter(Boolean);
}

function noopScore(cmd){
  const s = cmd.trim();
  if (!s) return 1;
  const lines = s.split("\n").map(x=>x.trim()).filter(Boolean);
  let noop=true;
  for (const l of lines){
    if (/^(echo\b|true$|:)$/.test(l)) continue;
    if (/^exit\s+0\s*;?$/.test(l)) continue;
    if (/^set -e/.test(l)) continue;
    if (/^trap\b/.test(l)) continue;
    noop=false; break;
  }
  return noop ? 1 : 0;
}

function hasAllowlistedGate(cmd){
  const s = cmd.replace(/\r/g,"");
  const allow = [
    /\.?[/\\]scripts[/\\]ci_[A-Za-z0-9_.-]+\.ps1\b/,
    /\bnode\s+scripts[/\\][A-Za-z0-9_.-]+\.mjs\b/,
    /\bnpm\s+run\s+(truth-bootstrap|env:sanity|stop-the-line|stop-the-line-xor|toolchain:contract|main-moved-guard|truth:sync|foundation:invariants)\b/,
    /\bdocker\s+run\b.*\bgitleaks\b.*\bdetect\b/
  ];
  return allow.some(r=>r.test(s));
}

function findJobByCheckName(checkName, workflowsParsed){
  // checkName format: "<workflow name> / <job display name>"
  const m = checkName.split(" / ");
  if (m.length < 2) return null;
  const wf = m[0].trim();
  const jobDisp = m.slice(1).join(" / ").trim();
  for (const w of workflowsParsed){
    if (w.wfName !== wf) continue;
    for (const j of w.jobs.values()){
      if (j.display === jobDisp) return { wfName: w.wfName, job: j, file: w.file };
    }
  }
  return null;
}

function main(){
  const workflows = listWorkflows();
  const parsed = workflows.map(f=>{
    const p = parseWorkflowJobs(f);
    return { file: f, wfName: p.wfName, jobs: p.jobs };
  });

  const required = loadRequiredChecks();
  const strict = (process.env.SEMANTIC_STRICT||"").toLowerCase()==="true";

  console.log("=== ci-semantic-contract ===");
  console.log("STRICT_MODE=", strict ? "true" : "false");
  console.log("WORKFLOWS_INSPECTED=", workflows.length);
  for (const f of workflows) console.log(" -", f);

  console.log("REQUIRED_CHECKS=");
  for (const r of required) console.log(" -", r);

  let ok=true;
  for (const r of required){
    const found = findJobByCheckName(r, parsed);
    if (!found){
      console.log("FAIL MISSING_REQUIRED_JOB:", r);
      ok=false; continue;
    }

    const runs = found.job.runs || [];
    const allow = runs.some(hasAllowlistedGate);
    const allNoop = runs.length>0 && runs.every(x=>noopScore(x)===1);

    console.log(`CHECK ${r}`);
    console.log("  FILE:", found.file);
    console.log("  JOB_ID:", found.job.id);
    console.log("  RUN_STEPS:", runs.length);
    console.log("  ALLOWLISTED_GATE:", allow ? "YES" : "NO");
    console.log("  NOT_NOOP:", allNoop ? "NO" : "YES");

    if (!allow){ console.log("  FAIL REASON: NO_ALLOWLISTED_GATE"); ok=false; }
    if (allNoop){ console.log("  FAIL REASON: NOOP_ONLY"); ok=false; }
  }

  if (ok){
    console.log("RESULT=PASS");
    process.exit(0);
  }

  if (strict){
    console.log("RESULT=FAIL");
    process.exit(1);
  } else {
    console.log("RESULT=ALERT_ONLY_FAIL");
    process.exit(0);
  }
}

main();


