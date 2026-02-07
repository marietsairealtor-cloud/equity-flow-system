import fs from "node:fs";
const p="scripts/green_gate.mjs";
let s=fs.readFileSync(p,"utf8");
if(s.includes("lint:sql")) { console.log("already wired"); process.exit(0); }
const lines=s.split("\n");
const idx=lines.findIndex(l=>l.includes("lint:migrations"));
if(idx<0) throw new Error("ANCHOR_NOT_FOUND: lint:migrations");
const indent=(lines[idx].match(/^\s*/)??[""])[0];
lines.splice(idx+1,0,`${indent}await run('npm run lint:sql');`);
fs.writeFileSync(p,lines.join("\n")+"\n","utf8");
console.log("wired lint:sql");
