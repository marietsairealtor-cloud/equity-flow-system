import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const dir = path.join(root, "supabase", "migrations");

if (!fs.existsSync(dir)) {
  console.error("MISSING: supabase/migrations");
  process.exit(1);
}

const files = fs.readdirSync(dir).filter(f => f.endsWith(".sql")).sort();

let ok = true;
const nameRe = new RegExp("^\\d{14}_.+\\.sql$");
const tsCount = new Map();

function fail(msg) { console.error("FAIL:", msg); ok = false; }
function warn(msg) { console.warn("WARN:", msg); }

for (const f of files) {
  if (!nameRe.test(f)) fail("Bad migration filename: " + f + " (expected 14-digit timestamp prefix)");

  const ts = f.slice(0, 14);
  tsCount.set(ts, (tsCount.get(ts) ?? 0) + 1);

  const p = path.join(dir, f);
  const buf = fs.readFileSync(p);

  // UTF-8 BOM check
  if (buf.length >= 3 && buf[0] === 0xEF && buf[1] === 0xBB && buf[2] === 0xBF) {
    fail("UTF-8 BOM detected: " + f + " (must be UTF-8 NO BOM)");
  }

  // NUL byte check
  if (buf.includes(0x00)) {
    fail("NUL byte detected: " + f);
  }
}

for (const [ts, c] of tsCount.entries()) {
  if (c > 1) warn("Duplicate timestamp prefix " + ts + " appears " + c + "x (allowed; order is by full filename)");
}

if (!ok) process.exit(1);
console.log("lint:migrations OK");