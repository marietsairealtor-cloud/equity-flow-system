#!/usr/bin/env node
/**
 * 2.16.4B CI Topology Audit (No Phantom Gates)
 * Authority: docs/truth/required_checks.json (required check run names)
 * Checks:
 *  - Each truth name exists as <workflow.name> / <job.name||jobId> in workflows.
 *  - In .github/workflows/ci.yml, jobs.required.needs contains ALL CI-workflow truth job IDs.
 */
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import yaml from "yaml";

const ROOT = process.cwd();
const WF_DIR = path.join(ROOT, ".github", "workflows");
const AUTH = path.join(ROOT, "docs", "truth", "required_checks.json");
const CI_YML = path.join(WF_DIR, "ci.yml");
const read=(p)=>fs.readFileSync(p,"utf8");
const die=(m)=>{ console.error(m); process.exit(1); };
const listWf=()=>fs.readdirSync(WF_DIR).filter(f=>/\.ya?ml$/.test(f)).map(f=>path.join(WF_DIR,f));
const parse=(fp)=>{ const src=read(fp); return {doc: yaml.parse(src), src}; };
const grepLn=(src,re)=>{ const L=src.split(/\r?\n/); for(let i=0;i<L.length;i++) if(re.test(L[i])) return i+1; return null; };
const esc=(s)=>s.replace(/[.*+?^${}()|[\]\\]/g,"\\$&");
function loadTruth(){
  if(!fs.existsSync(AUTH)) die(`ERROR: missing authority ${path.relative(ROOT,AUTH)}`);
  const j=JSON.parse(read(AUTH));
  const checks=Array.isArray(j.checks)?j.checks:[];
  const req=checks.filter(c=>c&&c.required===true).map(c=>c.name);
  if(req.length===0) die(`ERROR: no required checks in ${path.relative(ROOT,AUTH)}`);
  return req;
}
function indexWorkflows(files){
  const all=new Set(); const map=new Map();
  for(const fp of files){
    const rel=path.relative(ROOT,fp); const {doc,src}=parse(fp);
    const wf=doc?.name; if(!wf||typeof wf!=="string"){ const ln=grepLn(src,/^name:/); die(`ERROR: workflow missing name ${rel}${ln?`:${ln}`:""}`); }
    const jobs=doc?.jobs; if(!jobs||typeof jobs!=="object"){ const ln=grepLn(src,/^jobs:/); die(`ERROR: workflow missing jobs ${rel}${ln?`:${ln}`:""}`); }
    for(const [jobId,job] of Object.entries(jobs)){
      const jobName=(job&&typeof job==="object"&&typeof job.name==="string")?job.name:jobId;
      const check=`${wf} / ${jobName}`; all.add(check);
      if(!map.has(check)){
        const ln=grepLn(src,new RegExp(`^\\s{2}${esc(jobId)}:\\s*$`));
        map.set(check,{workflow:wf,jobId,workflowFile:rel,jobIdLn:ln});
      }
    }
  }
  return {all,map};
}
function readRequiredNeeds(){
  const {doc,src}=parse(CI_YML); const rel=path.relative(ROOT,CI_YML);
  const jobs=doc?.jobs; if(!jobs||typeof jobs!=="object") die(`ERROR: ci.yml missing jobs ${rel}`);
  const req=jobs.required; if(!req||typeof req!=="object") die(`ERROR: ci.yml missing jobs.required ${rel}`);
  if(!Array.isArray(req.needs)) die(`ERROR: jobs.required.needs not array ${rel}`);
  const ln=grepLn(src,/^  required:\s*$/) || grepLn(src,/^    needs:/);
  return {needs:req.needs, rel, ln};
}
function main(){
  const truth=loadTruth(); const files=listWf();
  const {all,map}=indexWorkflows(files); const {needs,rel,ln}=readRequiredNeeds();
  const missingTruth=truth.filter(t=>!all.has(t));
  const ciTruth=truth.filter(t=>t.startsWith("CI / "));
  const missingNeeds=[];
  for(const t of ciTruth){
    const rec=map.get(t); if(!rec) continue;
    if(!needs.includes(rec.jobId)) missingNeeds.push({t,jobId:rec.jobId,where:`${rec.workflowFile}${rec.jobIdLn?`:${rec.jobIdLn}`:""}`});
  }
  if(missingTruth.length===0 && missingNeeds.length===0){ console.log("OK: ci-topology-audit PASS"); process.exit(0); }
  console.error("FAIL: ci-topology-audit"); console.error(`Authority: ${path.relative(ROOT,AUTH)}`);
  if(missingTruth.length){ console.error("\nMissing truth check names:"); missingTruth.forEach(x=>console.error(` - ${x}`)); }
  if(missingNeeds.length){ console.error(`\nrequired.needs missing CI job IDs in ${rel}${ln?`:${ln}`:""}:`); missingNeeds.forEach(m=>console.error(` - "${m.t}" -> "${m.jobId}" (from ${m.where})`));
    console.error(`\nCurrent required.needs: [${needs.join(", ")}]`); }
  process.exit(1);
}
main();
