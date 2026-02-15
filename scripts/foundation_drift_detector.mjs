import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";

function sh(cmd){
  return execSync(cmd,{stdio:["ignore","pipe","pipe"]}).toString("utf8").trim();
}

function tryReadEvent(){
  const ep = process.env.GITHUB_EVENT_PATH || "";
  if(!ep || !fs.existsSync(ep)) return null;
  try { return JSON.parse(fs.readFileSync(ep,"utf8")); } catch { return null; }
}

function getShas(){
  const ev = tryReadEvent();
  const pr = ev?.pull_request;
  const base = process.env.BASE_SHA || pr?.base?.sha || "";
  const head = process.env.HEAD_SHA || pr?.head?.sha || "";
  return { base, head };
}

function listChanged(base, head){
  try { sh(`git fetch --no-tags origin ${base} ${head}`); } catch {}
  try {
    return sh(`git diff --name-only ${base}..${head}`)
      .split(/\r?\n/).filter(Boolean);
  } catch { return []; }
}

function hasFoundationTouch(changed){
  return changed.some(f => f.startsWith("supabase/foundation/"));
}

export function detectFoundationDriftClass(){
  const { base, head } = getShas();
  if(!base || !head) return "";
  const changed = listChanged(base, head);
  if(hasFoundationTouch(changed)) return "FOUNDATION_DRIFT";
  return "";
}