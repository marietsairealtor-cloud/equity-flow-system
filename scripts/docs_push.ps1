$ErrorActionPreference = "Stop"

# Refuse detached HEAD
$branch = (& git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -eq "HEAD") {
  throw "Blocked: docs:push refused -- detached HEAD. Checkout a branch first."
}

# Refuse main
if ($branch -eq "main") {
  throw "Blocked: docs:push refused -- cannot push directly to main. Open a PR."
}

# Require clean tree
$dirty = (& git status --porcelain)
if ($dirty) {
  throw "Blocked: docs:push refused -- working tree not clean. Commit all changes first."
}

# Refuse if diff touches robot-owned paths
$robotOwned = @("generated/", "docs/proofs/", "docs/handoff_latest.txt", "docs/proofs/manifest.json")
$changed = (& git diff --name-only origin/main...HEAD)
foreach ($path in $robotOwned) {
  $hit = $changed | Where-Object { $_.StartsWith($path) }
  if ($hit) {
    throw "Blocked: docs:push refused -- diff touches robot-owned path: $hit"
  }
}

# Non-docs files check
$nonDocs = $changed | Where-Object { $_ -and ($_ -notlike "docs/*") }
if ($nonDocs.Count -gt 0) {
  throw "Blocked: docs:push refused -- non-doc files in diff:`n$($nonDocs -join "`n")"
}

Write-Host "docs:push checks passed. Branch: $branch"
Write-Host "DOCS_PUSH_CONTRACT_OK"