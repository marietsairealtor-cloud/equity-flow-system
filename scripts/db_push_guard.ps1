if($env:ALLOW_REMOTE -ne "1"){ Write-Error "REMOTE_PUSH_BLOCKED: set ALLOW_REMOTE=1 to run db:push"; exit 1 }
npx supabase db push
