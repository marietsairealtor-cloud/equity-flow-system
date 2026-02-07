$files = git status --porcelain | ForEach-Object { $_.Substring(3) }
$nonDocs = $files | Where-Object { $_ -and ($_ -notlike "docs/*") }
if ($nonDocs.Count -gt 0) {
  Write-Error "docs:push refused. Non-doc files modified:`n$($nonDocs -join "`n")"
  exit 1
}
git add docs/*
git commit -m "Docs: update"
git push