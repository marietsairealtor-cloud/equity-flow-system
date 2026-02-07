$ErrorActionPreference = "Stop"

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

& (Join-Path $ScriptDir "gen_schema.ps1") | Out-String | Out-Null

$diff = (git diff --name-only -- generated/schema.sql 2>&1 | Out-String).Trim()
if ($diff.Length -gt 0) {
  Write-Host "SCHEMA DRIFT: generated/schema.sql changed. Diff follows:"
  git --no-pager diff -- generated/schema.sql
  throw "SCHEMA DRIFT: commit updated generated/schema.sql (or fix migration ordering)."
}

Write-Host "SCHEMA DRIFT CHECK OK"
