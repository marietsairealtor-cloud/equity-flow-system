$ErrorActionPreference="Stop"

$pkg = Get-Content package.json -Raw | ConvertFrom-Json
$scripts = $pkg.scripts.psobject.Properties.Name

function RunIf([string]$name){
  if($scripts -contains $name){
    Write-Host "== $name =="
    npm run -s $name
  } else {
    Write-Host "== $name (skip: missing) =="
  }
}

RunIf "preflight:encoding"
RunIf "lint"
RunIf "test"
RunIf "toolchain:contract"
RunIf "truth:sync"
RunIf "truth:check"
RunIf "proof:manifest"

Write-Host "== proof-commit-binding =="
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ci_proof_commit_binding.ps1
