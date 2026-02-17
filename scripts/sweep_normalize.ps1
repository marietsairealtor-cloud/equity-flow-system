# sweep_normalize.ps1 — 2.17.1
$paths = @("docs","generated","supabase")
foreach ($p in $paths) { git add --renormalize $p 2>&1 | Out-Null }
$diff = git diff --cached --name-only
if ($diff) {
  Write-Host "FAIL: renormalization diff detected:`n$diff"
  git reset HEAD $paths 2>&1 | Out-Null
  exit 1
}
git reset HEAD $paths 2>&1 | Out-Null
Write-Host "PASS: no renormalization diff detected."
exit 0
