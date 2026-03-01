import fs from "node:fs";
import path from "node:path";

// 2.16.5C Foundation Invariants Suite
// Validates Foundation surface against generated/schema.sql (schema truth).
// No live DB required — structural validation only.

const schemaPath = path.join("generated", "schema.sql");
const guardrailsPath = path.join("docs", "artifacts", "GUARDRAILS.md");
const selectorPath = path.join("docs", "truth", "tenant_table_selector.json");

if (!fs.existsSync(schemaPath)) {
  console.error("FAIL: generated/schema.sql not found");
  process.exit(1);
}

const schema = fs.readFileSync(schemaPath, "utf8");
let failures = [];

// === 1. Tenant isolation ===
if (!/CREATE\s+(OR\s+REPLACE\s+)?FUNCTION\s+"public"\."current_tenant_id"/i.test(schema)) {
  failures.push("TENANT_ISOLATION: current_tenant_id() function not found in schema");
}

if (fs.existsSync(selectorPath)) {
  const selector = JSON.parse(fs.readFileSync(selectorPath, "utf8"));
  const tenantTables = selector.tenant_owned_tables || [];
  for (const t of tenantTables) {
    const rlsRe = new RegExp(`ALTER\\s+TABLE\\s+"public"\\."${t}"\\s+ENABLE\\s+ROW\\s+LEVEL\\s+SECURITY`, "i");
    if (!rlsRe.test(schema)) {
      failures.push(`TENANT_ISOLATION: RLS not enabled on tenant-owned table "${t}"`);
    }
  }
} else {
  failures.push("TENANT_ISOLATION: tenant_table_selector.json not found");
}

console.log(!failures.some(f => f.startsWith("TENANT_ISOLATION"))
  ? "PASS: 1/5 Tenant isolation — current_tenant_id() exists, RLS enabled on all tenant-owned tables"
  : failures.filter(f => f.startsWith("TENANT_ISOLATION")).join("\n"));

// === 2. Role enforcement ===
if (!/CREATE\s+TYPE\s+"public"\."tenant_role"\s+AS\s+ENUM/i.test(schema)) {
  failures.push("ROLE_ENFORCEMENT: tenant_role enum not found in schema");
} else {
  // Verify all three values present
  const enumBlock = schema.match(/CREATE\s+TYPE\s+"public"\."tenant_role"\s+AS\s+ENUM\s*\(([^)]+)\)/i);
  if (enumBlock) {
    const vals = enumBlock[1];
    for (const v of ["owner", "admin", "member"]) {
      if (!vals.includes(`'${v}'`)) {
        failures.push(`ROLE_ENFORCEMENT: tenant_role enum missing value '${v}'`);
      }
    }
  }
}

if (!/"role"\s+"public"\."tenant_role"/.test(schema)) {
  failures.push("ROLE_ENFORCEMENT: tenant_memberships.role column not found in schema");
}

console.log(!failures.some(f => f.startsWith("ROLE_ENFORCEMENT"))
  ? "PASS: 2/5 Role enforcement — tenant_role enum and membership role column exist"
  : failures.filter(f => f.startsWith("ROLE_ENFORCEMENT")).join("\n"));

// === 3. Entitlement truth compiles ===
if (!fs.existsSync(guardrailsPath)) {
  failures.push("ENTITLEMENT_TRUTH: GUARDRAILS.md not found");
} else {
  const guardrails = fs.readFileSync(guardrailsPath, "utf8");
  if (!/get_user_entitlements_v1/i.test(guardrails)) {
    failures.push("ENTITLEMENT_TRUTH: entitlement source declaration not found in GUARDRAILS.md");
  }
}

console.log(!failures.some(f => f.startsWith("ENTITLEMENT_TRUTH"))
  ? "PASS: 3/5 Entitlement truth compiles — GUARDRAILS §17 declares entitlement source path"
  : failures.filter(f => f.startsWith("ENTITLEMENT_TRUTH")).join("\n"));

// === 4. Activity log write path ===
if (!/CREATE\s+TABLE\s+(IF\s+NOT\s+EXISTS\s+)?"public"\."activity_log"/i.test(schema)) {
  failures.push("ACTIVITY_LOG: activity_log table not found in schema");
}
if (!/CREATE\s+(OR\s+REPLACE\s+)?FUNCTION\s+"public"\."foundation_log_activity_v1"/i.test(schema)) {
  failures.push("ACTIVITY_LOG: foundation_log_activity_v1 RPC not found in schema");
}

console.log(!failures.some(f => f.startsWith("ACTIVITY_LOG"))
  ? "PASS: 4/5 Activity log write path — table and RPC exist"
  : failures.filter(f => f.startsWith("ACTIVITY_LOG")).join("\n"));

// === 5. Cross-tenant negative ===
const permissiveRe = /CREATE\s+POLICY\s+\S+\s+ON\s+"public"\.\S+[\s\S]*?USING\s*\(\s*\(?true\)?\s*\)/i;
if (permissiveRe.test(schema)) {
  failures.push("CROSS_TENANT_NEGATIVE: permissive USING(true) policy found — cross-tenant leak risk");
}

if (!/CREATE\s+POLICY[\s\S]*?"public"\."current_tenant_id"\(\)/i.test(schema)) {
  failures.push("CROSS_TENANT_NEGATIVE: no RLS policies reference current_tenant_id()");
}

console.log(!failures.some(f => f.startsWith("CROSS_TENANT_NEGATIVE"))
  ? "PASS: 5/5 Cross-tenant negative — no permissive policies, current_tenant_id() enforced"
  : failures.filter(f => f.startsWith("CROSS_TENANT_NEGATIVE")).join("\n"));

// === Summary ===
if (failures.length > 0) {
  console.error("\nFOUNDATION_INVARIANTS FAIL:");
  failures.forEach(f => console.error("  " + f));
  process.exit(1);
} else {
  console.log("\nFOUNDATION_INVARIANTS PASS (5/5)");
  process.exit(0);
}
