import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

function run(label, cmd, args, opts = {}) {
  console.log("\n=== " + label + " ===");
  console.log([cmd, ...args].join(" "));
  const r = spawnSync(cmd, args, {
    stdio: "inherit",
    shell: process.platform === "win32",
    env: { ...process.env, ...(opts.env || {}) },
  });
  const code = r.status ?? 1;
  if (!opts.allowFail && code !== 0) process.exit(code);
  return code;
}

function hasFile(p) {
  return fs.existsSync(p);
}

/** Get Supabase DB container name (supabase_db_*). */
function getDbContainer() {
  const r = spawnSync("docker", ["ps", "--format", "{{.Names}}"], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  if (r.status !== 0) return null;
  const names = (r.stdout || "").trim().split(/\r?\n/).filter(Boolean);
  const db = names.find((n) => n.includes("supabase_db_"));
  return db || null;
}

/** Run SQL in DB container via stdin. */
function psqlStdin(container, sql) {
  const r = spawnSync(
    "docker",
    ["exec", "-i", container, "psql", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1"],
    {
      input: sql,
      encoding: "utf8",
      stdio: ["pipe", "inherit", "inherit"],
    }
  );
  return r.status === 0;
}

/** DB-only reset: drop public (+ extensions), re-run migrations + seed. Avoids CLI "Restarting containers" 502. */
function runDbOnlyReset() {
  const label = "db reset (DB-only, docker)";
  console.log("\n=== " + label + " ===");

  const db = getDbContainer();
  if (!db) {
    console.error("No supabase_db_* container found. Is Supabase running?");
    process.exit(1);
  }

  const migrationsDir = path.join(process.cwd(), "supabase", "migrations");
  const seedPath = path.join(process.cwd(), "supabase", "seed.sql");
  if (!fs.existsSync(migrationsDir)) {
    console.error("supabase/migrations not found");
    process.exit(1);
  }

  const migrationFiles = fs
    .readdirSync(migrationsDir)
    .filter((f) => f.endsWith(".sql"))
    .sort();

  const resetSql = [
    "DROP SCHEMA IF EXISTS public CASCADE;",
    "CREATE SCHEMA public;",
    "GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;",
    "DROP SCHEMA IF EXISTS extensions CASCADE;",
    "CREATE SCHEMA extensions;",
    "GRANT USAGE ON SCHEMA extensions TO anon, authenticated, service_role;",
  ].join("\n");

  if (!psqlStdin(db, resetSql)) {
    console.error("Reset SQL failed");
    process.exit(1);
  }

  for (const f of migrationFiles) {
    const fullPath = path.join(migrationsDir, f);
    const sql = fs.readFileSync(fullPath, "utf8");
    console.log("Applying " + f);
    if (!psqlStdin(db, sql)) {
      console.error("Migration failed: " + f);
      process.exit(1);
    }
  }

  if (fs.existsSync(seedPath)) {
    const seedSql = fs.readFileSync(seedPath, "utf8");
    console.log("Seeding supabase/seed.sql");
    if (!psqlStdin(db, seedSql)) {
      console.error("Seed failed");
      process.exit(1);
    }
  }
}

const mode = process.argv[2] ?? "once";
if (!["once", "twice"].includes(mode)) {
  console.error("Usage: node scripts/green_gate.mjs once|twice");
  process.exit(2);
}

const passes = mode === "twice" ? 2 : 1;

// Exclude vector (often unstable) + don’t block on health checks.
const startArgs = ["supabase", "start", "-x", "vector", "--ignore-health-check"];

for (let pass = 1; pass <= passes; pass++) {
  console.log("\n====================");
  console.log("PASS " + pass + " / " + passes);
  console.log("====================");

  // Hard reset: delete volumes, then start fresh (avoids db reset 502 path).
  run("supabase stop --no-backup", "npx", ["supabase", "stop", "--no-backup"], { allowFail: true });
  run("supabase start", "npx", startArgs);
  run("supabase status", "npx", ["supabase", "status"]);

  // DB-only reset via Docker (avoids CLI "Restarting containers" 502); matches CI flow (start -> db reset).
  runDbOnlyReset();

  run("lint:migrations", "npm", ["run", "lint:migrations"]);
  run("lint:sql", "npm", ["run", "lint:sql"]);
  run("lint:pgtap", "npm", ["run", "lint:pgtap"]);
  run("build", "npm", ["run", "build"]);

  // NOTE: handoff removed. Publishing/proof artifacts handled in PR lane via handoff_commit.ps1.
}

console.log("\nALL GREEN: " + passes + " consecutive pass(es) completed.");
