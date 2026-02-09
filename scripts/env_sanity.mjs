import { execSync } from "node:child_process";
import path from "node:path";

function sh(cmd){
  return execSync(cmd, { stdio: ["ignore","pipe","pipe"], encoding: "utf8" });
}
function safe(cmd){
  try { return { ok:true, out: sh(cmd) }; } catch(e){
    const out = (e.stdout?.toString?.() ?? "") + (e.stderr?.toString?.() ?? "");
    return { ok:false, out };
  }
}

const proj = path.basename(process.cwd());
const info = safe("docker info");
if(!info.ok){
  console.error("ENV_SANITY FAIL: docker not available");
  console.error(info.out.trim());
  process.exit(1);
}

const c = safe(`docker ps -a --filter "label=com.supabase.project=${proj}" --format "{{.ID}}"`);
const v = safe(`docker volume ls --filter "label=com.supabase.project=${proj}" --format "{{.Name}}"`);
const n = safe(`docker network ls --filter "label=com.supabase.project=${proj}" --format "{{.ID}}"`);

const cs = (c.out||"").split(/\r?\n/).filter(Boolean);
const vs = (v.out||"").split(/\r?\n/).filter(Boolean);
const ns = (n.out||"").split(/\r?\n/).filter(Boolean);

console.log(`ENV_SANITY project=${proj} containers=${cs.length} volumes=${vs.length} networks=${ns.length}`);
if(cs.length || vs.length || ns.length){
  console.log("ENV_SANITY FAIL: run scripts/docker_cleanup_project.ps1 then retry");
  process.exit(1);
}
console.log("ENV_SANITY PASS");
process.exit(0);