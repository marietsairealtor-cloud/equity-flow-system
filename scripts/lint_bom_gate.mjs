import fs from "node:fs";

const files = process.argv.slice(2);
if (!files.length) process.exit(0);

const bad = [];

for (const f of files) {
  try {
    const b = fs.readFileSync(f);

    // UTF-8 BOM: EF BB BF
    if (b.length >= 3 && b[0] === 0xEF && b[1] === 0xBB && b[2] === 0xBF) {
      bad.push({ file: f, reason: "UTF-8 BOM (EF BB BF)" });
      continue;
    }
    // UTF-16 LE/BE BOM: FF FE / FE FF
    if (b.length >= 2 && ((b[0] === 0xFF && b[1] === 0xFE) || (b[0] === 0xFE && b[1] === 0xFF))) {
      bad.push({ file: f, reason: "UTF-16 BOM (FF FE / FE FF)" });
      continue;
    }
  } catch (e) {}
}

if (bad.length) {
  console.error("BOM_GATE FAIL: BOM detected in staged files:");
  for (const x of bad) console.error(`- ${x.file}: ${x.reason}`);
  console.error("\nFix: run `npm run fix:encoding` (or rewrite as UTF-8 without BOM).");
  process.exit(1);
}

process.exit(0);