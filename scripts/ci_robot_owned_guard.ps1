$ErrorActionPreference = "Stop"

git fetch origin main | Out-Null
$base = "origin/main"

function Norm([string]$p){
  return ($p.Trim() -replace "\\","/").TrimStart("./")
}

function GlobToRegex([string]$glob){
  $g = Norm $glob
  $g = [Regex]::Escape($g)
  # ** => .*
  $g = $g -replace "\\\*\\\*",".*"
  # * => [^/]* (single segment)
  $g = $g -replace "\\\*","[^/]*"
  return "^" + $g + "$"
}

function IsRobotOwned([string]$p, $patterns){
  $pp = Norm $p
  foreach($pat in $patterns){
    $rx = GlobToRegex $pat
    if($pp -match $rx){ return $true }
    # also allow prefix-match for "root/**" style paths
    $root = (Norm $pat) -replace "/\*\*.*$",""
    if($root -and $pp.StartsWith($root + "/")){ return $true }
    if($root -and $pp -eq $root){ return $true }
  }
  return $false
}

function ExceptionMatch([string]$p){
  $pp = Norm $p
  if($pp -eq "docs/proofs/manifest.json"){ return "ALLOW:manifest.json" }
  if($pp -match "^docs/proofs/2\.17\.4_parser_fixture_check_\d{8}T\d{6}Z\.log$"){ return "ALLOW:2.17.4 proof log" }
  if($pp -match "^docs/proofs/2\.16\.10_robot_owned_guard_\d{8}T\d{6}Z\.log$"){ return "ALLOW:2.16.10 proof log" }
  if($pp -match "^docs/proofs/2\.16\.11_governance_change_template_\d{8}T\d{6}Z\.log$"){ return "ALLOW:2.16.11 proof log" }
  if($pp -match "^docs/proofs/2\.17\.1_normalize_sweep_\d{8}T\d{6}Z\.log$"){ return "ALLOW:2.17.1 proof log" }
  if($pp -match "^docs/proofs/2\.17\.1A_proof_finalize_arg_hardening_\d{8}T\d{6}Z\.log$"){ return "ALLOW:2.17.1A proof log" }
if($pp -match "^docs/proofs/2\.17\.2_encoding_audit_\d{8}T\d{6}Z\.log$"){ return "ALLOW:2.17.2 proof log" }
  if($pp -eq "docs/proofs/_archive/2.5_truth_bootstrap_20260208_231039Z.log"){ return "ALLOW:archive 2.5 repaired log" }
  if($pp -eq "docs/proofs/2.5_truth_bootstrap_20260208_231412Z.log"){ return "ALLOW:2.5 repaired log" }
  if($pp -eq "docs/proofs/2.6_required_checks_contract_20260208_232749Z.log"){ return "ALLOW:2.6 repaired log" }
  if($pp -eq "docs/proofs/2.7_docs_only_ci_skip_20260208_234320Z.log"){ return "ALLOW:2.7 repaired log" }
  if($pp -eq "docs/proofs/2.16.2A_hash_authority_contract_20260211_161401Z.log"){ return "ALLOW:2.16.2A repaired log" }
  if($pp -match "^docs/proofs/2\.17\.3_path_leak_audit_\d{8}T\d{6}Z\.log$"){ return "ALLOW:2.17.3 proof log" }
  if($pp -eq "docs/proofs/4.1_cloud_baseline_20260219_144802.md"){ return "ALLOW:4.1 proof log" }
  if($pp -match "^docs/proofs/4\.2_toolchain_versions_supabase_\d{8}T\d{6}Z\.log$"){ return "ALLOW:4.2 proof log" }
  if($pp -match "^docs/proofs/4\.2a_command_smoke_db_\d{8}T\d{6}Z\.log$"){ return "ALLOW:4.2A proof log" }
  if($pp -match "^docs/proofs/3\.1_automation_contract_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.1 proof log" }
  if($pp -match "^docs/proofs/3\.2_ship_guard_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.2 proof log" }
  if($pp -match "^docs/proofs/3\.3_handoff_commit_push_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.3 proof log" }
  if($pp -match "^docs/proofs/3\.4_docs_push_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.4 proof log" }
  if($pp -match "^docs/proofs/3\.5_qa_requirements_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.5 proof log" }
  if($pp -match "^docs/proofs/3\.6_robot_owned_publish_guard_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.6 proof log" }
  if($pp -match "^docs/proofs/3\.7_qa_verify_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.7 proof log" }
  if($pp -match "^docs/proofs/3\.8_handoff_idempotency_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.8 proof log" }
  if($pp -match "^docs/proofs/3\.9\.1_deferred_proof_registry_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.9.1 proof log" }
  if($pp -match "^docs/proofs/3\.9\.2_governance_path_coverage_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.9.2 proof log" }
  if($pp -match "^docs/proofs/3\.9\.3_qa_scope_coverage_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.9.3 proof log" }
  if($pp -match "^docs/truth/qa_claim\.json$"){ return "ALLOW:qa_claim.json" }
  if($pp -match "^docs/truth/qa_scope_map\.json$"){ return "ALLOW:qa_scope_map.json" }
  if($pp -match "^docs/proofs/3\.7_qa_verify_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.7 proof log" }
  if($pp -match "^docs/proofs/3\.8_handoff_idempotency_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.8 proof log" }
  if($pp -match "^docs/proofs/3\.9\.1_deferred_proof_registry_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.9.1 proof log" }
  if($pp -match "^docs/proofs/3\.9\.2_governance_path_coverage_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.9.2 proof log" }
  if($pp -match "^docs/proofs/3\.9\.3_qa_scope_coverage_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.9.3 proof log" }
  if($pp -match "^docs/proofs/qa_claim\.json$"){ return "ALLOW:qa_claim.json" }
  if($pp -match "^docs/truth/qa_scope_map\.json$"){ return "ALLOW:qa_scope_map.json" }
  if($pp -match "^docs/proofs/3\.5_qa_requirements_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.5 proof log" }
  if($pp -eq "docs/handoff_latest.txt"){ return "ALLOW:handoff artifact" }
  if($pp -eq "generated/contracts.snapshot.json"){ return "ALLOW:handoff artifact" }
  if($pp -eq "generated/schema.sql"){ return "ALLOW:handoff artifact" }

  # Allowed historical proof repairs (SOP §3.2) — explicit file allowlist
  if($pp -eq "docs/proofs/1.3_denylist_20260208_002421.log"){ return "ALLOW:1.3 repaired log" }
  if($pp -eq "docs/proofs/2.15_governance_change_20260210_001959Z.log"){ return "ALLOW:2.15 repaired log" }
  if($pp -eq "docs/proofs/2.17.1A_proof_finalize_arg_hardening_20260218T175242Z.log"){ return "ALLOW:2.17.1A repaired log" }
  if($pp -eq "docs/proofs/2.17.2_encoding_audit_20260218T214411Z.log"){ return "ALLOW:2.17.2 repaired log" }

  if($pp -eq "docs/proofs/_archive/1.3_ci_local_20260208_001355.log"){ return "ALLOW:archive 1.3 repaired log" }
  if($pp -eq "docs/proofs/_archive/1.3_denylist_20260208_001230.log"){ return "ALLOW:archive 1.3 repaired log" }
  if($pp -eq "docs/proofs/_archive/2.9_QA_BUNDLE_20260209_103215Z.txt"){ return "ALLOW:archive 2.9 repaired bundle" }
  return $null
}

$cfgPath = "docs/truth/robot_owned_paths.json"
if(!(Test-Path $cfgPath)){ Write-Error "MISSING: $cfgPath"; exit 1 }

$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
$patterns = @($cfg.paths | ForEach-Object { "$_" }) | Where-Object { $_ }

$raw = @(git diff --name-status "$base...HEAD" | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ })
$changed = @()
foreach($ln in $raw){
  $parts = $ln -split "`t"
  if($parts.Count -lt 2){ continue }
  $st = $parts[0]
  if($st -match "^R"){ $changed += (Norm $parts[2]); continue }
  $changed += (Norm $parts[1])
}
$changed = $changed | Sort-Object -Unique

$robot = @()
foreach($f in $changed){
  if(IsRobotOwned $f $patterns){ $robot += $f }
}

Write-Host "=== robot-owned-guard ==="
Write-Host ("BASE=" + $base)
Write-Host ("CHANGED_FILES=" + $changed.Count)
foreach($f in $changed){ Write-Host (" - " + $f) }

Write-Host "ROBOT_OWNED_CHANGED:"
if($robot.Count -eq 0){
  Write-Host " (none)"
  Write-Host "STATUS: PASS"
  exit 0
}
foreach($f in $robot){
  $ex = ExceptionMatch $f
  if($ex){
    Write-Host (" - " + $f + " :: " + $ex)
  } else {
    Write-Host (" - " + $f + " :: NO_EXCEPTION")
  }
}

$off = @()
foreach($f in $robot){
  if(-not (ExceptionMatch $f)){ $off += $f }
}

if($off.Count -gt 0){
  Write-Host "OFFENDING_PATHS:"
  foreach($f in $off){ Write-Host (" - " + $f + " :: robot-owned (no allowed exception)") }
  Write-Host "STATUS: FAIL"
  exit 1
}

Write-Host "STATUS: PASS"
exit 0
