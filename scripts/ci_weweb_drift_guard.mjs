// scripts/ci_weweb_drift_guard.mjs
// 10.2: WeWeb drift guard.
// Scans repo-owned files for forbidden /rest/v1/<table> direct access patterns.
// Fails if any forbidden endpoint is detected outside of allowed proof/doc paths.
// Lane-only until promoted to merge-blocking.

import fs from "node:fs";
import path from "node:path";

const ENDPOINTS_TRUTH_PATH = "docs/truth/weweb_endpoints_truth.json";

// Paths to scan for forbidden endpoint usage
const SCAN_DIRS = ["products", "docs/artifacts", "scripts"];
const SCAN_EXTENSIONS = [".js", ".mjs", ".ts", ".json", ".md", ".html", ".vue", ".jsx", ".tsx"];

// Paths to exclude from scan (proof docs may reference forbidden patterns as evidence)
const EXCLUDE_PATTERNS = [
  "docs/proofs/",
  "docs/truth/weweb_endpoints_truth.json",
  "scripts/ci_weweb_drift_guard.mjs",
  "scripts/test_postgrest_isolation.mjs"
];

function die(msg) {
  console.error(`ci_weweb_drift_guard: FAIL - ${msg}`);
  process.exit(1);
}

function shouldExclude(filePath) {
  const normalized = filePath.replace(/\\/g, "/");
  return EXCLUDE_PATTERNS.some(p => normalized.includes(p));
}

function scanDir(dir, forbidden, violations) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      scanDir(fullPath, forbidden, violations);
    } else if (entry.isFile() && SCAN_EXTENSIONS.includes(path.extname(entry.name))) {
      if (shouldExclude(fullPath)) continue;
      const content = fs.readFileSync(fullPath, "utf8");
      for (const pattern of forbidden) {
        if (content.includes(pattern)) {
          violations.push({ file: fullPath, pattern });
        }
      }
    }
  }
}

async function main() {
  console.log("=== ci_weweb_drift_guard ===");

  if (!fs.existsSync(ENDPOINTS_TRUTH_PATH)) {
    die(`${ENDPOINTS_TRUTH_PATH} not found`);
  }

  const truth = JSON.parse(fs.readFileSync(ENDPOINTS_TRUTH_PATH, "utf8"));
  const forbidden = truth.forbidden_patterns;

  console.log(`Forbidden patterns: ${forbidden.join(", ")}`);
  console.log(`Scanning: ${SCAN_DIRS.join(", ")}`);
  console.log("");

  const violations = [];
  for (const dir of SCAN_DIRS) {
    scanDir(dir, forbidden, violations);
  }

  if (violations.length > 0) {
    console.error("FAIL: forbidden direct table access patterns detected:");
    for (const v of violations) {
      console.error(`  ${v.file}: ${v.pattern}`);
    }
    die("WeWeb drift detected — forbidden /rest/v1/ table access found in repo");
  }

  console.log("No forbidden endpoint patterns detected in repo-owned files.");
  console.log(`Allowed RPC endpoints: ${truth.allowed_patterns.length}`);
  console.log(`Forbidden table endpoints checked: ${forbidden.length}`);
  console.log("ci_weweb_drift_guard: PASS");
}

main().catch(e => { console.error(e); process.exit(1); });