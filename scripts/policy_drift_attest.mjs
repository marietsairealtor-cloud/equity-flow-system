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

const token = process.env.POLICY_DRIFT_TOKEN || process.env.GH_TOKEN || process.env.GITHUB_TOKEN || "";
const tokenSource =
  process.env.POLICY_DRIFT_TOKEN ? "POLICY_DRIFT_TOKEN" :
  process.env.GH_TOKEN ? "POLICY_DRIFT_TOKEN" :
  process.env.GITHUB_TOKEN ? "GITHUB_TOKEN" :
  "MISSING";
if (!token) die("Missing GH_TOKEN/GITHUB_TOKEN in env.");
console.log(`TOKEN_SOURCE=${tokenSource}`);
import crypto from "node:crypto";
console.log(`TOKEN_LEN=${token.length}`);
console.log(`TOKEN_SHA256_8=${crypto.createHash("sha256").update(token,"utf8").digest("hex").slice(0,8)}`);

const repo = process.env.GITHUB_REPOSITORY;
if (!repo) die("Missing GITHUB_REPOSITORY.");

const apiBase = "https://api.github.com";
const headers = {
  "Accept": "application/vnd.github+json",
  "Authorization": `token ${token}`,
  "X-GitHub-Api-Version": "2022-11-28",
  "User-Agent": "policy-drift-attestation"
};

async function gh(path) {
  const url = `${apiBase}${path}`;
  console.error(`GET ${path}`);

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

  console.error(`HTTP ${r.status} ${path}`);

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

// Best-effort extraction of required status check contexts from a ruleset detail.
// GitHub ruleset schema can evolve; we store both raw matching rule blocks and normalized contexts.
function extractRequiredChecksFromRulesetDetail(detail) {
  const out = { contexts: [], matching_rules: [] };

  const rules = Array.isArray(detail?.rules) ? detail.rules : [];
  const contexts = new Set();

  for (const r of rules) {
    // Heuristic: required status checks rules typically contain "required_status_checks"
    // or parameters that include "required_check"/"required_checks"/"required_status_checks".
    const type = String(r?.type || "");
    const params = r?.parameters || r?.params || null;
    const blob = { type: type || null, parameters: params };

    const text = JSON.stringify(blob).toLowerCase();

    const looksRelevant =
      type.toLowerCase().includes("required") && (type.toLowerCase().includes("status") || type.toLowerCase().includes("check")) ||
      text.includes("required_status_checks") ||
      text.includes("required status checks") ||
      text.includes("required_checks") ||
      text.includes("required_check") ||
      text.includes("status_checks");

    if (!looksRelevant) continue;

    out.matching_rules.push(blob);

    // Try common shapes for contexts
    const candidates = [];
    if (params && Array.isArray(params.required_status_checks)) candidates.push(...params.required_status_checks);
    if (params && Array.isArray(params.required_checks)) candidates.push(...params.required_checks);
    if (params && Array.isArray(params.checks)) candidates.push(...params.checks);
    if (params && Array.isArray(params.contexts)) candidates.push(...params.contexts);

    // Some shapes use objects like { context: "CI / required" }
    for (const c of candidates) {
      if (typeof c === "string") contexts.add(c);
      else if (c && typeof c === "object") {
        if (typeof c.context === "string") contexts.add(c.context);
        if (typeof c.name === "string") contexts.add(c.name);
      }
    }
  }

  out.contexts = [...contexts].sort();
  return out;
}

const [owner, name] = repo.split("/");
const repoInfo = await gh(`/repos/${owner}/${name}`);
const branch = repoInfo?.default_branch || "main";

const rulesets = await gh(`/repos/${owner}/${name}/rulesets?per_page=100`);

// Fetch full ruleset details to capture required-check enforcement that branch protection endpoint may not expose.
const rulesetsDetailed = [];
for (const rs of Array.isArray(rulesets) ? rulesets : []) {
  const id = rs?.id;
  if (!id) continue;
  const detail = await gh(`/repos/${owner}/${name}/rulesets/${id}`);
  const extracted = extractRequiredChecksFromRulesetDetail(detail);
  rulesetsDetailed.push({
    id: detail?.id ?? id,
    name: detail?.name ?? rs?.name ?? null,
    target: detail?.target ?? rs?.target ?? null,
    enforcement: detail?.enforcement ?? rs?.enforcement ?? null,
    // Keep the ruleset URL references (useful for debugging)
    _links: detail?._links ?? rs?._links ?? null,
    // Store only the relevant extracted portions to reduce snapshot churn.
    required_checks_extracted: extracted,
  });
}

let protection = null;
try {
  protection = await gh(`/repos/${owner}/${name}/branches/${encodeURIComponent(branch)}/protection`);
} catch (e) {
  if (e.status === 404 || e.status === 403) protection = null;
  else die(`GitHub API FAIL ${e.status}: ${e.message}`);
}

const requiredChecksFromBranchProtection = protection?.required_status_checks
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

// Derive an effective required_checks view that includes ruleset-enforced required checks when branch protection is absent.
const derivedRulesetContexts = (() => {
  const s = new Set();
  for (const d of rulesetsDetailed) {
    for (const c of d?.required_checks_extracted?.contexts || []) s.add(c);
  }
  return [...s].sort();
})();

const requiredChecksEffective = {
  source: protection ? "branch_protection" : "rulesets_or_none",
  strict: requiredChecksFromBranchProtection.strict ?? null,
  contexts: requiredChecksFromBranchProtection.contexts?.length
    ? requiredChecksFromBranchProtection.contexts
    : derivedRulesetContexts,
  checks: requiredChecksFromBranchProtection.checks ?? [],
};

const adminBypass = {
  enforce_admins: protection?.enforce_admins?.enabled ?? null,
  allow_force_pushes: protection?.allow_force_pushes?.enabled ?? null,
  allow_deletions: protection?.allow_deletions?.enabled ?? null,
};

const current = {
  repo,
  branch,
  rulesets,
  rulesets_detailed: rulesetsDetailed,
  branch_protection: protection,
  required_checks: requiredChecksEffective,
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
