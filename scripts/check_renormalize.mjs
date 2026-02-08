import fs from "node:fs"; import { execSync } from "node:child_process";
const allow=[".gitattributes","docs/truth","docs/proofs","scripts",".github/workflows"].filter(p=>fs.existsSync(p));
execSync("git add --renormalize -- "+allow.map(p=>`"${p}"`).join(" "),{stdio:"inherit"});
const dirty=execSync("git status --porcelain",{encoding:"utf8"}).trim();
execSync("git reset --hard",{stdio:"inherit"});
if(dirty){console.error("RENORMALIZE_ENFORCED_FAIL:\n"+dirty);process.exit(1)}
console.log("RENORMALIZE_ENFORCED_OK");
