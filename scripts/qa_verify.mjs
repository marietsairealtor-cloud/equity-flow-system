import { readFileSync, existsSync } from "fs";

function readJson(path) {
  const s = readFileSync(path, "utf8");
  return JSON.parse(s.charCodeAt(0) === 0xFEFF ? s.slice(1) : s);
}

console.log("=== qa:verify ===");

// 1. Read qa_claim.json
const claimPath = "docs/truth/qa_claim.json";
if (!existsSync(claimPath)) {
  console.log("FAIL: docs/proofs/qa_claim.json missing -- every PR must declare its claimed item");
  process.exit(1);
}
const claim = readJson(claimPath);
if (!claim.item) {
  console.log("FAIL: qa_claim.json missing 'item' field");
  process.exit(1);
}
console.log("CLAIM:", claim.item);

// 2. Read qa_scope_map.json
const mapPath = "docs/truth/qa_scope_map.json";
if (!existsSync(mapPath)) {
  console.log("FAIL: docs/truth/qa_scope_map.json missing");
  process.exit(1);
}
const scopeMap = readJson(mapPath);
const itemEntry = scopeMap.items[claim.item];
if (!itemEntry) {
  console.log("FAIL: item '" + claim.item + "' not found in qa_scope_map.json");
  process.exit(1);
}
console.log("PATTERN:", itemEntry.proof_pattern);

// 3. Read manifest
const manifestPath = "docs/proofs/manifest.json";
if (!existsSync(manifestPath)) {
  console.log("FAIL: docs/proofs/manifest.json missing");
  process.exit(1);
}
const manifest = readJson(manifestPath);
const proofFiles = Object.keys(manifest.files || {});

// 4. Check required proof exists in manifest
const pattern = new RegExp(itemEntry.proof_pattern);
const matches = proofFiles.filter(f => pattern.test(f));
if (matches.length === 0) {
  console.log("FAIL: no proof found in manifest matching pattern:", itemEntry.proof_pattern);
  console.log("STATUS FAIL");
  process.exit(1);
}
console.log("PROOF_FOUND:", matches[matches.length - 1]);
console.log("STATUS PASS");
process.exit(0);
