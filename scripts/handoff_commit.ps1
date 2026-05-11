$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

# Encoding preflight (same shell as this script — avoids requiring `pwsh` on PATH)
& (Join-Path $PSScriptRoot "preflight_encoding.ps1")
if ($LASTEXITCODE -ne 0) {
  Write-Error "handoff:commit aborted: preflight_encoding.ps1 exited $LASTEXITCODE"
  exit $LASTEXITCODE
}

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
  if ($LASTEXITCODE -ne 0) {
    Write-Error "handoff:commit failed: could not create branch $prBranch"
    exit $LASTEXITCODE
  }
  $branch = $prBranch
  Write-Host "Switched to PR branch: $branch"
}
# Regenerate truth artifacts (local)
& npm run handoff
if ($LASTEXITCODE -ne 0) {
  Write-Error "handoff:commit aborted: npm run handoff exited $LASTEXITCODE"
  exit $LASTEXITCODE
}

# Stage only robot-owned truth artifacts
& git add `
  docs/handoff_latest.txt `
  generated/schema.sql `
  generated/contracts.snapshot.json `
  docs/truth/write_path_registry.json `
  docs/truth/cloud_migration_parity.json `
  docs/truth/tenant_table_selector.json `
  docs/truth/definer_allowlist.json `
  docs/truth/execute_allowlist.json
if ($LASTEXITCODE -ne 0) {
  Write-Error "handoff:commit failed: git add truth artifacts exited $LASTEXITCODE"
  exit $LASTEXITCODE
}

$staged = (& git diff --cached --name-only) 2>$null
if (-not $staged) {
  Write-Host "No truth artifact changes to commit."
  exit 0
}
& git commit -m "Update handoff artifacts"
if ($LASTEXITCODE -ne 0) {
  Write-Error "handoff:commit failed: git commit exited $LASTEXITCODE"
  exit $LASTEXITCODE
}

# Push the current branch (PR branch if started from main)
& git push -u origin $branch
if ($LASTEXITCODE -ne 0) {
  Write-Error "handoff:commit failed: git push exited $LASTEXITCODE (branch may not exist on origin). Fix network/GitHub and retry."
  exit $LASTEXITCODE
}
Write-Host "Pushed: $branch"