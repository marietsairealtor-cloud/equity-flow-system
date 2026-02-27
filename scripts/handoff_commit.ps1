$ErrorActionPreference = "Stop"
& pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/preflight_encoding.ps1
# Refuse detached HEAD
$branch = (& git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -eq "HEAD") {
  throw "Blocked: handoff:commit refused -- detached HEAD. Checkout a branch first."
}
# If on main, auto-create a PR branch (never commit/push main)
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
& git add docs/handoff_latest.txt generated/schema.sql generated/contracts.snapshot.json docs/truth/write_path_registry.json
$staged = (& git diff --cached --name-only) 2>$null
if (-not $staged) {
  Write-Host "No truth artifact changes to commit."
  exit 0
}
& git commit -m "Update handoff artifacts"
# Push the current branch (PR branch if started from main)
& git push -u origin $branch
Write-Host "Pushed: $branch"