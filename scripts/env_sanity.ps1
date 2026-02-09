param()
$ErrorActionPreference="Stop"
$proj = (Split-Path (Get-Location) -Leaf)
docker info | Out-Null
$cs = docker ps -a --filter "label=com.supabase.project=$proj" --format "{{.ID}}" 2>$null
$vs = docker volume ls --filter "label=com.supabase.project=$proj" --format "{{.Name}}" 2>$null
$ns = docker network ls --filter "label=com.supabase.project=$proj" --format "{{.ID}}" 2>$null
"ENV_SANITY project=$proj containers=$(@($cs).Count) volumes=$(@($vs).Count) networks=$(@($ns).Count)"
if(@($cs).Count -gt 0 -or @($vs).Count -gt 0 -or @($ns).Count -gt 0){ "ENV_SANITY FAIL: run scripts/docker_cleanup_project.ps1 then retry"; exit 1 }
"ENV_SANITY PASS"; exit 0