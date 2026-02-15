import fs from "node:fs";
import path from "node:path";

const name = process.argv[2];
if (!name || !/^[a-z0-9-]+$/.test(name)) {
  console.error("USAGE: npm run product:scaffold -- <product-name>  (lowercase letters/numbers/dashes)");
  process.exit(2);
}

const root = process.cwd();
const base = path.join(root, "products", name);

if (fs.existsSync(base)) {
  console.error("FAIL: target exists: " + path.relative(root, base));
  process.exit(3);
}

const mk = (rel) => fs.mkdirSync(path.join(base, rel), { recursive: true });
const w = (rel, txt) => {
  const fp = path.join(base, rel);
  const out = String(txt).replace(/\r\n/g, "\n");
  fs.writeFileSync(fp, out, { encoding: "utf8" });
};

mk("db");
mk("db/rls");
mk("ui");
mk("docs");

w("README.md", "# " + name + "\n\nScaffolded product shell.\n");
w("capabilities.json", JSON.stringify({ product: name, capabilities: {} }, null, 2) + "\n");
w("db/schema_placeholder.sql",
  "-- " + name + ": schema placeholder\n" +
  "-- NOTE: no $$ in SQL; use named dollar tags only if needed later.\n"
);
w("db/rls/rls_placeholder.sql", "-- " + name + ": RLS extension placeholder\n");
w("ui/README.md", "# UI shell\n\nAdd product UI here.\n");
w("docs/PROOFS.md", "# Proof templates\n\n- docs/proofs/2.16.5G_product_scaffold_generator_<UTC>.log\n");

console.log("OK: scaffolded " + path.relative(root, base));