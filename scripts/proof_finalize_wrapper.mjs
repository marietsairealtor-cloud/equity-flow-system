import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

function argError(reason) {
  process.stderr.write(`PROOF_FINALIZE_ARG_ERROR: ${reason}\n`);
  process.exit(1);
}

const rawArgs = process.argv.slice(2);

// Accept: positional #1 OR legacy "-File <path>"
let positional = null;
let legacy = null;

for (let i = 0; i < rawArgs.length; i++) {
  const a = rawArgs[i];
  if (a === "-File") {
    if (i + 1 >= rawArgs.length) argError("'-File' requires a following path");
    if (legacy !== null) argError("proof log path provided more than once");
    legacy = rawArgs[i + 1];
    i++;
    continue;
  }
}

// Positional rules: first non-flag token (doesn't start with '-') counts as positional.
for (let i = 0; i < rawArgs.length; i++) {
  const a = rawArgs[i];
  if (a === "-File") { i++; continue; }
  if (!a.startsWith("-")) {
    if (positional !== null) argError("proof log path provided more than once (positional)");
    positional = a;
  } else {
    // Disallow other flags to keep deterministic surface.
    argError(`unexpected argument '${a}'`);
  }
}

const provided = [positional, legacy].filter(v => v !== null);
if (provided.length === 0) argError("missing proof log path");
if (provided.length > 1) argError("proof log path provided more than once (positional + -File)");

const input = provided[0];

// Must be repo-relative (no absolute paths)
if (path.isAbsolute(input)) argError("path must be repo-relative under docs/proofs/");

// Normalize and prevent traversal
const repoRoot = process.cwd();
const resolved = path.resolve(repoRoot, input);
const relFromRoot = path.relative(repoRoot, resolved);

// If it escapes repo root, relative will start with '..' or be absolute
if (relFromRoot.startsWith("..") || path.isAbsolute(relFromRoot)) {
  argError("path must resolve inside repo");
}

// Must be under docs/proofs/
const relFwd = relFromRoot.split(path.sep).join("/");
if (!relFwd.startsWith("docs/proofs/")) {
  argError("path must be under docs/proofs/");
}

// Must exist
if (!fs.existsSync(resolved)) argError(`file does not exist: ${relFwd}`);

// Final value passed to PowerShell must use forward slashes
const proofPathForPwsh = relFwd;

// Spawn pwsh deterministically
const psArgs = [
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", "scripts/proof_finalize.ps1",
  "-File", proofPathForPwsh
];

const r = spawnSync("pwsh", psArgs, { stdio: "inherit" });

if (r.error) argError(`failed to launch pwsh: ${r.error.message}`);
process.exit(r.status ?? 1);
