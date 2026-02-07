import fs from "node:fs"; import path from "node:path";
const root=process.cwd(), dir=path.join(root,"supabase","tests");
const bad=[{re:/^\s*\\/m,msg:"psql meta command \\\\"},{re:/^\s*DO\b/m,msg:"DO block"}];
function walk(d){ if(!fs.existsSync(d)) return []; const out=[]; for(const e of fs.readdirSync(d,{withFileTypes:true})){ const p=path.join(d,e.name); if(e.isDirectory()) out.push(...walk(p)); else if(e.isFile() && p.endsWith(".pgtap.sql")) out.push(p);} return out;}
let ok=true; for(const f of walk(dir)){ const t=fs.readFileSync(f,"utf8"); for(const b of bad){ if(b.re.test(t)){ console.error(`LINT_PGTAP FAIL: ${b.msg} in ${path.relative(root,f)}`); ok=false; } } }
if(!ok) process.exit(1); console.log("LINT_PGTAP OK");