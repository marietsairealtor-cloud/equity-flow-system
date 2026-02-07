$ErrorActionPreference = "Stop"

# Boot local Supabase and apply migrations deterministically
npx supabase start
npx supabase db reset --yes