import fs from "node:fs";

function extractChecks(filePath) {
  const y = fs.readFileSync(filePath, "utf8");
  const wf = ((/^name:\s*(.+)$/m.exec(y) || [])[1] || "CI").trim();
  const m = /^\s{2}required:\s*$[\s\S]*?^\s{4}needs:\s*\[([^\]]+)\]/m.exec(y);
  if (!m) return [];
  const ids = m[1].split(",").map(s => s.trim()).filter(Boolean);
  return ids.map(id => {
    const re = new RegExp("^\\s{2}" + id + ":\\s*$([\\s\\S]*?)(?=^\\s{2}[A-Za-z0-9_-]+:\\s*$|\\Z)", "m");
    const b = re.exec(y);
    if (!b) throw new Error("job not found: " + id + " in " + filePath);
    const nm = (/^\s{4}name:\s*(.+)$/m.exec(b[1]) || [])[1];
    return { name: `${wf} / ${(nm || id).trim()}`, type: "github_status", required: true };
  });
}

function extractAllJobs(filePath) {
  const y = fs.readFileSync(filePath, "utf8");
  const wf = ((/^name:\s*(.+)$/m.exec(y) || [])[1] || "CI").trim();
  const jobMatches = [...y.matchAll(/^\s{2}([A-Za-z0-9_-]+):\s*\n([\s\S]*?)(?=^\s{2}[A-Za-z0-9_-]+:\s*\n|\Z)/gm)];
  return jobMatches
    .filter(m => {
      const body = m[2];
      // Only include jobs that have actual steps (not just needs/runs-on)
      return /^\s{4}steps:/m.test(body);
    })
    .map(m => {
      const id = m[1];
      const body = m[2];
      const nm = (/^\s{4}name:\s*(.+)$/m.exec(body) || [])[1];
      return { name: `${wf} / ${(nm || id).trim()}`, type: "github_status", required: true };
    });
}

// Derive from ci.yml required.needs (existing behavior)
const ciChecks = extractChecks(".github/workflows/ci.yml");

// Derive from database-tests.yml — all jobs are required
const dbChecks = extractAllJobs(".github/workflows/database-tests.yml");

// Merge, deduplicate by name, sort
const all = [...ciChecks, ...dbChecks];
const seen = new Set();
const checks = all
  .filter(c => { if (seen.has(c.name)) return false; seen.add(c.name); return true; })
  .sort((a, b) => a.name.localeCompare(b.name));

fs.writeFileSync("docs/truth/required_checks.json", JSON.stringify({ checks }, null, 2) + "\n", "utf8");
