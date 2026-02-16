import fs from "node:fs"; import {execFileSync} from "node:child_process";
const sh=(a)=>execFileSync(a[0],a.slice(1),{encoding:"utf8",stdio:["ignore","pipe","pipe"]}).trim();
const pol=JSON.parse(fs.readFileSync("docs/truth/waiver_policy.json","utf8"));
const DAYS=Number(pol.window_days); const MAX=Number(pol.max_waivers_in_window);
let log=""; try{ log=sh(["git","log",`--since=${DAYS}.days`,`--name-only`,`--pretty=format:--%H`,"--","docs/waivers"]); }catch{ log=""; }
const lines=log.split(/\r?\n/).map(l=>l.trim()).filter(Boolean);
const waivers=new Set(); for(const l of lines){ if(/^docs\/waivers\/WAIVER_PR\d+\.md$/.test(l)) waivers.add(l); }
console.log("=== waiver-rate-limit ==="); console.log("WINDOW_DAYS=",DAYS); console.log("MAX_WAIVERS_IN_WINDOW=",MAX); console.log("WAIVERS_TOUCHED=",waivers.size);
if(waivers.size){ console.log("WAIVER_FILES="); [...waivers].sort().forEach(f=>console.log(" -",f)); }
if(waivers.size>MAX){ console.log("RESULT=FAIL"); console.error("HARD_FAIL: waiver rate limit exceeded"); process.exit(1); }
console.log("RESULT=PASS"); process.exit(0);
