$ErrorActionPreference = "Stop"

& powershell -NoProfile -ExecutionPolicy Bypass -File scripts/preflight_encoding.ps1

# If on main, auto-create a PR branch (never commit/push main)
$branch = (& git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -eq "main") {
  $sha = (& git rev-parse --short HEAD).Trim()
  $prBranch = "pr/handoff-artifacts-$sha"
  & git checkout -b $prBranch
  $branch = $prBranch
  Write-Host "Switched to PR branch: $branch"
}

# Regenerate truth artifacts (local)
& npm run handoff

# Stage only robot-owned truth artifacts
& git add docs/handoff_latest.txt generated/schema.sql generated/contracts.snapshot.json

$staged = (& git diff --cached --name-only) 2>$null
if (-not $staged) {
  Write-Host "No truth artifact changes to commit."
  exit 0
}

& git commit -m "Update handoff artifacts"

# Push the current branch (PR branch if started from main)
& git push -u origin $branch
Write-Host "Pushed: $branch"
