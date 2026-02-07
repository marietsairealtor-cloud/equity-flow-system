import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

function cmd(name) {
  if (process.platform !== "win32") return name;
  if (name === "npm") return "npm.cmd";
  if (name === "npx") return "npx.cmd";
  if (name === "powershell") return "powershell.exe";
  if (name === "git") return "git.exe";
  if (name === "node") return "node.exe";
  return name;
}

function run(bin, args, inherit = true) {
  const r = spawnSync(bin, args, {
    stdio: inherit ? "inherit" : ["ignore", "pipe", "pipe"],
    shell: false,
  });
  const code = r.status ?? 1;
  if (code !== 0) process.exit(code);
  return r;
}

function captureRaw(bin, args) {
  const r = spawnSync(bin, args, { stdio: ["ignore", "pipe", "pipe"], shell: false });
  const code = r.status ?? 1;
  const out = (r.stdout ?? Buffer.from("")).toString("utf8");
  const err = (r.stderr ?? Buffer.from("")).toString("utf8");
  if (code !== 0) {
    if (err.trim()) console.error(err.trimEnd());
    process.exit(code);
  }
  // keep leading spaces (needed for git porcelain); only trim final newline
  return out.replace(/\r?\n$/, "");
}

function captureTrim(bin, args) {
  return captureRaw(bin, args).trim();
}

function findGh() {
  // PATH
  const t = spawnSync("gh", ["--version"], { stdio: "ignore", shell: false });
  if ((t.status ?? 1) === 0) return "gh";

  const pf = process.env.ProgramFiles || "C:\\Program Files";
  const la = process.env.LOCALAPPDATA || "";
  const candidates = [
    path.join(pf, "GitHub CLI", "gh.exe"),
    path.join(pf, "GitHub CLI", "bin", "gh.exe"),
    path.join(la, "Programs", "GitHub CLI", "gh.exe"),
    path.join(la, "Programs", "GitHub CLI", "bin", "gh.exe"),
  ];
  for (const p of candidates) if (fs.existsSync(p)) return p;

  console.error("gh not found. Install GitHub CLI or add it to PATH.");
  process.exit(1);
}

function repoFromOrigin() {
  const origin = captureTrim(cmd("git"), ["remote", "get-url", "origin"]);
  // https://github.com/OWNER/REPO(.git)
  let m = origin.match(/github\.com[/:]([^/]+)\/([^/\.]+)(\.git)?$/);
  if (m) return m[1] + "/" + m[2];
  return null;
}

function listWorkflowFiles() {
  const dir = path.join(process.cwd(), ".github", "workflows");
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir)
    .filter((f) => f.endsWith(".yml") || f.endsWith(".yaml"))
    .sort();
}

const argv = new Set(process.argv.slice(2));
const skipGreen = argv.has("--skip-green");

// ship.mjs = GATES ONLY.
// - No auto-commit
// - No git push
// - No CI polling / workflow triggering
// Publishing artifacts belongs in handoff_commit.ps1 PR lane.

const gh = findGh();

// ensure gh is authenticated (optional but keeps workflow checks honest)
{
  const r = spawnSync(gh, ["auth", "status", "-h", "github.com"], { stdio: "inherit", shell: false });
  if ((r.status ?? 1) !== 0) {
    console.error("Not authenticated in gh. Run: gh auth login");
    process.exit(r.status ?? 1);
  }
}

// set default repo (more reliable gh behavior)
{
  const repo = repoFromOrigin();
  if (repo) run(gh, ["repo", "set-default", repo]);
}

// choose required workflows by files present
const wfFiles = listWorkflowFiles();
const requiredFiles = new Set();

if (wfFiles.includes("database-tests.yml")) requiredFiles.add("database-tests.yml");
if (wfFiles.includes("database-tests.yaml")) requiredFiles.add("database-tests.yaml");
for (const f of wfFiles) {
  const n = f.toLowerCase();
  if (n.includes("ci") || n.includes("policy")) requiredFiles.add(f);
}

// load workflows from GitHub and map local required files => workflow databaseId
const wfJson = captureRaw(gh, ["workflow", "list", "--json", "id,name,path,state"]);
let workflows = [];
try {
  workflows = JSON.parse(wfJson || "[]");
} catch {
  workflows = [];
}

function norm(p) {
  return String(p || "").replace(/\\/g, "/");
}
function endsWithPath(full, file) {
  const a = norm(full);
  const b = ".github/workflows/" + file;
  return a.endsWith(b);
}

const required = [];
for (const file of requiredFiles) {
  const hit = workflows.find((w) => endsWithPath(w.path, file));
  if (!hit) {
    console.error("Required workflow not found on GitHub for file: " + file);
    process.exit(1);
  }
  if ((hit.state || "").toLowerCase() !== "active") {
    console.error("Workflow is not active: " + hit.name + " (" + hit.path + ")");
    process.exit(1);
  }
  required.push({ workflowDatabaseId: String(hit.id), name: hit.name, path: hit.path, file });
}

if (required.length === 0) {
  console.error("No workflows found to require. Ensure .github/workflows exists.");
  process.exit(1);
}

console.log("Required workflows (validated on GitHub):");
for (const r of required) console.log(" - " + r.name + " | " + r.path);

// local proof
if (!skipGreen) {
  console.log("\nRunning local proof: npm run green:twice");
  run(cmd("node"), ["scripts/green_gate.mjs", "twice"]);
}

const branch = captureTrim(cmd("git"), ["rev-parse", "--abbrev-ref", "HEAD"]);
const headSha = captureTrim(cmd("git"), ["rev-parse", "HEAD"]);

console.log("\nbranch: " + branch);
console.log("head:   " + headSha);

console.log("\nGATES PASSED.");
process.exit(0);
