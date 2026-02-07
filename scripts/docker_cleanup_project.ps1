param([switch] $Force = $true)
$ErrorActionPreference = "Stop"

$repoName = Split-Path -Leaf (Resolve-Path ".").Path

try { & npx supabase stop --no-backup | Out-Null } catch {}

$containers = & docker ps -a --format '{{.ID}}|{{.Names}}|{{.Status}}|{{.Labels}}' 2>$null
if (!$containers) { Write-Host "No docker containers found."; exit 0 }

$ids = @()
foreach ($line in $containers) {
  $parts = $line -split " ",3
  $id = $parts[0]
  $name = $parts[1]
  $label = if ($parts.Count -ge 3) { $parts[2] } else { "" }

  if ($name -like "*$repoName*" -or $label -eq $repoName) { $ids += $id }
}

$ids = $ids | Sort-Object -Unique
if ($ids.Count -eq 0) { Write-Host "No project-scoped containers matched repo '$repoName'."; exit 0 }

if ($Force) { & docker rm -f $ids | Out-Null } else { & docker rm $ids | Out-Null }

Write-Host "Removed $($ids.Count) project-scoped containers for repo '$repoName'."