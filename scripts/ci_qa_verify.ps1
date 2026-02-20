$ErrorActionPreference = "Stop"
Write-Host "=== qa-verify ==="
& node scripts/qa_verify.mjs
if ($LASTEXITCODE -ne 0) { exit 1 }
exit 0