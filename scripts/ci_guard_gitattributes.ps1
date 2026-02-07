$expected = @'
.gitattributes text eol=lf
docs/handoff_latest.txt text eol=lf
generated/schema.sql text eol=lf
generated/contracts.snapshot.json text eol=lf
scripts/*.ps1 text eol=lf
*.yml text eol=lf
*.yaml text eol=lf
*.md text eol=lf
*.sql text eol=lf
*.txt text eol=lf
*.env.example text eol=lf
*.mjs text eol=lf
'@ + "`n"
$actual = (Get-Content .gitattributes -Raw) -replace "`r`n","`n"
if($actual -ne $expected){ Write-Error "CI_GUARD_FAIL: .gitattributes differs from expected. Revert or update guard intentionally."; exit 1 }
"CI_GUARD_OK: .gitattributes matches expected"
