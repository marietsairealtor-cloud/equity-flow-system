// retention-lifecycle/index.ts
// Supabase Edge Function -- daily retention lifecycle automation
// Invoked by GitHub Actions scheduled workflow at 02:00 UTC daily
// Requires x-retention-secret header matching RETENTION_LIFECYCLE_SECRET

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req: Request) => {
  try {
    // Validate invocation secret
    const expectedSecret = Deno.env.get('RETENTION_LIFECYCLE_SECRET')
    const incomingSecret = req.headers.get('x-retention-secret')

    if (!expectedSecret) {
      console.error('retention-lifecycle: RETENTION_LIFECYCLE_SECRET not configured')
      return new Response(
        JSON.stringify({ ok: false, error: 'Server misconfiguration' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (!incomingSecret || incomingSecret !== expectedSecret) {
      console.error('retention-lifecycle: unauthorized invocation attempt')
      return new Response(
        JSON.stringify({ ok: false, error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(
        JSON.stringify({ ok: false, error: 'Missing environment configuration' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    const client = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false }
    })

    const { data, error } = await client.rpc('process_workspace_retention_v1')

    if (error) {
      console.error('retention-lifecycle: RPC error', error)
      return new Response(
        JSON.stringify({ ok: false, error: error.message }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log('retention-lifecycle: completed', JSON.stringify(data))

    return new Response(
      JSON.stringify(data),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )

  } catch (err) {
    console.error('retention-lifecycle: unexpected error', err)
    return new Response(
      JSON.stringify({ ok: false, error: 'Internal retention lifecycle error' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})