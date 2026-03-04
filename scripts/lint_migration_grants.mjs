#!/usr/bin/env node
/**
 * lint_migration_grants.mjs
 *
 * Build Route 7.2 — Migration GRANT lint gate
 *
 * Scans supabase/migrations/**\/*.sql for any GRANT or ALTER DEFAULT PRIVILEGES
 * statement targeting `anon` or `authenticated`. Fails if any found grant is not
 * on the explicit allowlist in docs/truth/privilege_truth.json.
 *
 * The allowlist is the single authority. Documentation comments in migration files
 * are NOT a control mechanism. An undocumented GRANT fails the gate regardless of
 * any comments present. Authority: CONTRACTS.md §12.
 *
 * superseded_grants: historical grants that predate this gate and are provably
 * revoked by a named later migration are skipped — but only if the superseding
 * migration file exists on disk. The skip is conditional, not unconditional.
 *
 * Static analysis only — no database connection required.
 * Gate name: migration-grant-lint (merge-blocking)
 */

import fs from "node:fs";
import path from "node:path";

// ---------------------------------------------------------------------------
// File walker (no globSync dependency — works on Node 18+)
// ---------------------------------------------------------------------------
function findSqlFiles(dir) {
  const results = [];
  if (!fs.existsSync(dir)) return results;
  const walk = (d) => {
    for (const entry of fs.readdirSync(d, { withFileTypes: true })) {
      const full = path.join(d, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.isFile() && entry.name.endsWith(".sql")) results.push(full);
    }
  };
  walk(dir);
  return results;
}

// ---------------------------------------------------------------------------
// Load truth file
// ---------------------------------------------------------------------------
const TRUTH_PATH = "docs/truth/privilege_truth.json";
if (!fs.existsSync(TRUTH_PATH)) {
  console.error(`FAIL: ${TRUTH_PATH} not found — cannot determine allowlist`);
  process.exit(1);
}

let truth;
try {
  truth = JSON.parse(fs.readFileSync(TRUTH_PATH, "utf8"));
} catch (e) {
  console.error(`FAIL: ${TRUTH_PATH} is not valid JSON — ${e.message}`);
  process.exit(1);
}

const allowlist = truth.migration_grant_allowlist;
if (!allowlist) {
  console.error(`FAIL: ${TRUTH_PATH} missing migration_grant_allowlist section`);
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Build allowlist lookup structures
// ---------------------------------------------------------------------------
const allowedAuthTable = new Map(); // table -> Set<privilege>
for (const entry of (allowlist.authenticated_tables || [])) {
  allowedAuthTable.set(
    entry.table.toLowerCase(),
    new Set(entry.privileges.map((p) => p.toUpperCase()))
  );
}

const allowedAuthRoutine = new Set(
  (allowlist.authenticated_routines || []).map((r) => r.toLowerCase())
);

const allowedDefaultPrivs = new Set(
  (allowlist.alter_default_privileges || []).map((e) =>
    JSON.stringify({ role: e.role?.toLowerCase(), type: e.type?.toLowerCase() })
  )
);

// ---------------------------------------------------------------------------
// Build superseded grants lookup
// Map: normalised migration path -> Set of "role:table:priv" or "role:routine" keys
// A finding is suppressed only if:
//   1. The migration file matches a superseded_grants entry
//   2. The superseding migration exists on disk
// ---------------------------------------------------------------------------
const supersededByFile = new Map(); // rel path -> { keys: Set<string>, superseded_by: string }

for (const entry of (truth.superseded_grants?.entries || [])) {
  const migRel = entry.migration.replace(/\\/g, "/");
  const supersedingPath = entry.superseded_by.replace(/\\/g, "/");

  if (!fs.existsSync(supersedingPath)) {
    console.error(
      `FAIL: superseded_grants entry references superseding migration that does not exist on disk: ${supersedingPath}`
    );
    process.exit(1);
  }

  const keys = new Set();
  for (const g of (entry.grants || [])) {
    const role = g.role.toLowerCase();
    const table = g.table.toLowerCase();
    for (const priv of g.privileges) {
      keys.add(`${role}:table:${table}:${priv.toUpperCase()}`);
    }
  }

  supersededByFile.set(migRel, { keys, superseded_by: supersedingPath });
  console.log(
    `  NOTE: superseded grants registered for ${migRel} (revoked by ${supersedingPath})`
  );
}

// ---------------------------------------------------------------------------
// Regex patterns
// ---------------------------------------------------------------------------

// GRANT <privs> ON [TABLE|SEQUENCE|ALL ...] <name> TO <role>
const GRANT_TABLE_RE =
  /GRANT\s+([\w\s,]+?)\s+ON\s+(?:(TABLE|SEQUENCE|ALL\s+TABLES\s+IN\s+SCHEMA|ALL\s+SEQUENCES\s+IN\s+SCHEMA)\s+)?(\S+?)\s+TO\s+(anon|authenticated)\b/gi;

// GRANT EXECUTE ON FUNCTION/PROCEDURE/ROUTINE <name>(...) TO <role>
const GRANT_ROUTINE_RE =
  /GRANT\s+EXECUTE\s+ON\s+(?:FUNCTION|PROCEDURE|ROUTINE)\s+(\S+?)(?:\([^)]*\))?\s+TO\s+(anon|authenticated)\b/gi;

// ALTER DEFAULT PRIVILEGES ... GRANT ... TO <role>
const ALTER_DEFAULT_RE =
  /ALTER\s+DEFAULT\s+PRIVILEGES\b[^;]*?GRANT\b[^;]*?TO\s+(anon|authenticated)\b/gi;

// ---------------------------------------------------------------------------
// Scan
// ---------------------------------------------------------------------------
const MIGRATIONS_DIR = "supabase/migrations";
const sqlFiles = findSqlFiles(MIGRATIONS_DIR);

if (sqlFiles.length === 0) {
  console.log("migration-grant-lint: no migration files found — PASS (vacuous)");
  process.exit(0);
}

console.log(`migration-grant-lint: scanning ${sqlFiles.length} migration file(s)...`);

const failures = [];
let passCount = 0;
let supersededCount = 0;

for (const filePath of sqlFiles.sort()) {
  const raw = fs.readFileSync(filePath, "utf8");
  const content = raw.replace(/\r\n/g, "\n").replace(/\r/g, "\n");

  // Strip single-line comments
  const stripped = content
    .split("\n")
    .map((line) => { const i = line.indexOf("--"); return i >= 0 ? line.slice(0, i) : line; })
    .join("\n");
  // Strip block comments
  const noBlock = stripped.replace(/\/\*[\s\S]*?\*\//g, " ");

  const rel = filePath.replace(/\\/g, "/");
  const superseded = supersededByFile.get(rel);

  let m;

  // --- Table / sequence grants ---
  const tableRe = new RegExp(GRANT_TABLE_RE.source, "gi");
  while ((m = tableRe.exec(noBlock)) !== null) {
    const privStr = m[1].trim().toUpperCase();
    const objTypeRaw = (m[2] || "TABLE").trim().toUpperCase();
    const objName = m[3].replace(/^public\./, "").trim().toLowerCase();
    const role = m[4].trim().toLowerCase();
    const privs = privStr.split(",").map((p) => p.trim());

    if (objTypeRaw.startsWith("ALL")) {
      failures.push(`${rel}: GRANT ${privStr} ON ${objTypeRaw} TO ${role} — blanket grant forbidden (CONTRACTS.md §12)`);
      continue;
    }

    if (objTypeRaw === "SEQUENCE") {
      failures.push(`${rel}: GRANT ${privStr} ON SEQUENCE ${objName} TO ${role} — no sequence grants allowed (CONTRACTS.md §12)`);
      continue;
    }

    for (const priv of privs) {
      // Check superseded first
      if (superseded?.keys.has(`${role}:table:${objName}:${priv}`)) {
        supersededCount++;
        console.log(`  SUPERSEDED: ${rel}: GRANT ${priv} ON TABLE ${objName} TO ${role} — revoked by ${superseded.superseded_by}`);
        continue;
      }

      if (role === "anon") {
        failures.push(`${rel}: GRANT ${priv} ON TABLE ${objName} TO anon — not in allowlist (CONTRACTS.md §12)`);
      } else {
        const allowed = allowedAuthTable.get(objName);
        if (!allowed || !allowed.has(priv)) {
          failures.push(`${rel}: GRANT ${priv} ON TABLE ${objName} TO authenticated — not in allowlist (CONTRACTS.md §12)`);
        } else {
          passCount++;
          console.log(`  PASS: ${rel}: GRANT ${priv} ON TABLE ${objName} TO authenticated — allowlisted`);
        }
      }
    }
  }

  // --- Routine grants ---
  const routineRe = new RegExp(GRANT_ROUTINE_RE.source, "gi");
  while ((m = routineRe.exec(noBlock)) !== null) {
    const routineName = m[1].replace(/^public\./, "").trim().toLowerCase();
    const role = m[2].trim().toLowerCase();

    if (role === "anon") {
      failures.push(`${rel}: GRANT EXECUTE ON FUNCTION ${routineName} TO anon — not in allowlist (CONTRACTS.md §12)`);
    } else {
      if (!allowedAuthRoutine.has(routineName)) {
        failures.push(`${rel}: GRANT EXECUTE ON FUNCTION ${routineName} TO authenticated — not in allowlist (CONTRACTS.md §12)`);
      } else {
        passCount++;
        console.log(`  PASS: ${rel}: GRANT EXECUTE ON FUNCTION ${routineName} TO authenticated — allowlisted`);
      }
    }
  }

  // --- ALTER DEFAULT PRIVILEGES ---
  const altRe = new RegExp(ALTER_DEFAULT_RE.source, "gi");
  while ((m = altRe.exec(noBlock)) !== null) {
    const role = m[1].trim().toLowerCase();
    const snippet = m[0].replace(/\s+/g, " ").trim().slice(0, 120);
    const key = JSON.stringify({ role, type: "alter_default" });
    if (!allowedDefaultPrivs.has(key)) {
      failures.push(`${rel}: ALTER DEFAULT PRIVILEGES ... GRANT ... TO ${role} — not in allowlist: "${snippet}" (CONTRACTS.md §12)`);
    } else {
      passCount++;
      console.log(`  PASS: ${rel}: ALTER DEFAULT PRIVILEGES TO ${role} — allowlisted`);
    }
  }
}

// ---------------------------------------------------------------------------
// Result
// ---------------------------------------------------------------------------
console.log("");
console.log(`migration-grant-lint: ${passCount} allowlisted, ${supersededCount} superseded, ${failures.length} violation(s)`);

if (failures.length > 0) {
  console.error("FAIL: unauthorized GRANT(s) detected in migration files:");
  for (const f of failures) {
    console.error(`  - ${f}`);
  }
  console.error("Authority: CONTRACTS.md §12 / docs/truth/privilege_truth.json migration_grant_allowlist");
  console.error("STATUS: FAIL");
  process.exit(1);
}

console.log("STATUS: PASS");
process.exit(0);
