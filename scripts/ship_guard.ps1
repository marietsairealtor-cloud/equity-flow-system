$ErrorActionPreference = "Stop"

& powershell -NoProfile -ExecutionPolicy Bypass -File scripts/preflight_encoding.ps1

# ShipMergeEnforcement: refuse publish unless on main
$branch = (& git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne "main") {
  throw "Blocked: npm run ship only allowed on main (current: $branch). Merge PR to main first."
}

# Enforce clean tree on main
$dirty = (& git status --porcelain)
if ($dirty) { throw "Blocked: working tree not clean. Commit via PR, then rerun ship on main." }

# Verify artifacts already published (no regeneration here)
$diff = (& git diff --name-only -- generated/schema.sql generated/contracts.snapshot.json docs/handoff_latest.txt)
if ($diff) {
  throw "Blocked: artifacts/handoff not published. Run: npm run handoff && npm run handoff:commit (PR), merge, then rerun ship."
}


# Optional: docker hygiene
& powershell -NoProfile -ExecutionPolicy Bypass -File scripts/docker_cleanup_project.ps1

# Publish (inner must not commit; it should only run gates and any publish steps)
& npm run ship:inner
