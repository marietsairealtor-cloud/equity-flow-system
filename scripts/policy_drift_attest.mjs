import fs from "node:fs";

const SNAP_PATH = "docs/truth/github_policy_snapshot.json";
function die(msg, code = 1) { console.error(msg); process.exit(code); }

function sortKeysDeep(x) {
  if (Array.isArray(x)) return x.map(sortKeysDeep);
  if (x && typeof x === "object") {
    const out = {};
    for (const k of Object.keys(x).sort()) out[k] = sortKeysDeep(x[k]);
    return out;
  }
  return x;
}
function stableJson(x) { return JSON.stringify(sortKeysDeep(x), null, 2) + "\n"; }

const token = process.env.GH_TOKEN || process.env.GITHUB_TOKEN;
if (!token) die("Missing GH_TOKEN/GITHUB_TOKEN in env.");
const repo = process.env.GITHUB_REPOSITORY;
if (!repo) die("Missing GITHUB_REPOSITORY.");

const apiBase = "https://api.github.com";
const headers = {
  "Accept": "application/vnd.github+json",
  "Authorization": `Bearer ${token}`,
  "X-GitHub-Api-Version": "2022-11-28",
  "User-Agent": "policy-drift-attestation"
};

async function gh(path) {
  const url = `${apiBase}${path}`;
  console.error(`GET ${url}`);

  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), 20000);

  let r;
  try {
    r = await fetch(url, { headers, signal: ac.signal });
  } catch (e) {
    clearTimeout(t);
    die(`FETCH ERROR ${url}: ${e.name || "Error"} ${e.message || e}`);
  }
  clearTimeout(t);

  const txt = await r.text();
  let json = null;
  try { json = txt ? JSON.parse(txt) : null; } catch {}

  if (!r.ok) {
    const msg = json?.message || txt || "(no body)";
    const err = new Error(msg);
    err.status = r.status;
    throw err;
  }
  return json;
}

const [owner, name] = repo.split("/");
const repoInfo = await gh(`/repos/${owner}/${name}`);
const branch = repoInfo?.default_branch || "main";

const rulesets = await gh(`/repos/${owner}/${name}/rulesets?per_page=100`);

let protection = null;
try {
  protection = await gh(`/repos/${owner}/${name}/branches/${encodeURIComponent(branch)}/protection`);
} catch (e) {
  if (e.status === 404) protection = null;
  else die(`GitHub API FAIL ${e.status}: ${e.message}`);
}

const requiredChecks = protection?.required_status_checks
  ? {
      strict: protection.required_status_checks.strict ?? null,
      contexts: Array.isArray(protection.required_status_checks.contexts)
        ? [...protection.required_status_checks.contexts].sort()
        : [],
      checks: Array.isArray(protection.required_status_checks.checks)
        ? [...protection.required_status_checks.checks].map(c => ({
            context: c.context ?? null,
            app_id: c.app_id ?? null,
          })).sort((a,b)=>String(a.context).localeCompare(String(b.context)))
        : [],
    }
  : { strict: null, contexts: [], checks: [] };

const adminBypass = {
  enforce_admins: protection?.enforce_admins?.enabled ?? null,
  allow_force_pushes: protection?.allow_force_pushes?.enabled ?? null,
  allow_deletions: protection?.allow_deletions?.enabled ?? null,
};

const current = {
  repo,
  branch,
  rulesets,
  branch_protection: protection,
  required_checks: requiredChecks,
  admin_bypass_flags: adminBypass,
};

const curNorm = stableJson(current);

if (process.env.WRITE_SNAPSHOT === "1") {
  fs.mkdirSync("docs/truth", { recursive: true });
  fs.writeFileSync(SNAP_PATH, curNorm, "utf8");
  console.log(`WROTE snapshot: ${SNAP_PATH}`);
  process.exit(0);
}

if (!fs.existsSync(SNAP_PATH)) die(`Missing snapshot at ${SNAP_PATH} (must be committed).`);

let snap = null;
try { snap = JSON.parse(fs.readFileSync(SNAP_PATH, "utf8")); }
catch { die(`Snapshot is not valid JSON: ${SNAP_PATH}`); }

if (stableJson(snap) !== curNorm) {
  console.error("POLICY DRIFT DETECTED: snapshot != current");
  process.stderr.write(curNorm);
  process.exit(2);
}

console.log("OK: GitHub policy matches committed snapshot.");
