// create-restore-checkout-session/index.ts
// 10.8.11P support -- Archived workspace recovery checkout
// Decodes JWT sub from Authorization header (claim parsing only, not cryptographic verification).
// Fetches verified email via service role admin.getUserById() using decoded sub.
// Accepts restore_token from request body -- validated against server-returned archived list.
// Resolves tenant_id from restore_token server-side for Stripe subscription metadata.
// Ownership and archive eligibility are enforced server-side via list_archived_workspaces_v1()
// called with the caller's bearer token -- auth.uid() resolves inside the RPC.
// Creates Stripe Checkout session returning to /onboarding, not /today.

import Stripe from 'https://esm.sh/stripe@13.11.0'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
})

const serviceClient = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
)

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, content-type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
      },
    })
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }

  // Extract and validate bearer token
  const authHeader = req.headers.get('Authorization') ?? ''
  if (!authHeader.startsWith('Bearer ')) {
    return new Response(JSON.stringify({ error: 'Missing or malformed Authorization header' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
  const token = authHeader.slice(7).trim()
  if (!token) {
    return new Response(JSON.stringify({ error: 'Empty bearer token' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }

  // Decode JWT payload (claim parsing only -- not cryptographic verification).
  // Ownership and identity are enforced server-side via the RPC called with this token.
  let userId: string
  try {
    const payload = JSON.parse(atob(token.split('.')[1]))
    if (!payload?.sub) throw new Error('No sub in JWT payload')
    userId = payload.sub
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid token payload' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }

  // Fetch verified email via service role admin lookup by user ID.
  // Does not re-verify JWT -- uses sub only for lookup, not for authorization.
  const { data: { user: verifiedUser }, error: userError } = await serviceClient.auth.admin.getUserById(userId)
  if (userError || !verifiedUser) {
    console.error('User lookup error:', JSON.stringify(userError))
    return new Response(JSON.stringify({ error: 'Failed to resolve user' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
  const customerEmail = verifiedUser.email ?? undefined

  // Read restore_token from request body -- identifies the selected archived workspace
  let requestedRestoreToken: string | null = null
  try {
    const body = await req.json()
    requestedRestoreToken = body?.restore_token ?? null
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid request body' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }

  if (!requestedRestoreToken) {
    return new Response(JSON.stringify({ error: 'restore_token is required' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
  const priceId = Deno.env.get('STRIPE_PRICE_ID')
  const appUrl = Deno.env.get('APP_URL')

  if (!priceId) {
    return new Response(JSON.stringify({ error: 'Stripe price not configured' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }

  if (!appUrl) {
    return new Response(JSON.stringify({ error: 'APP_URL not configured' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }

  // Call list_archived_workspaces_v1() as the authenticated caller.
  // auth.uid() resolves inside the RPC via the bearer token.
  // Ownership and archive state are enforced server-side.
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  })

  const { data: archivedList, error: archivedError } = await userClient.rpc('list_archived_workspaces_v1')

  if (archivedError) {
    console.error('Archived workspace list error:', JSON.stringify(archivedError))
    return new Response(JSON.stringify({ error: 'Failed to load archived workspaces' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }

  const items = archivedList?.data?.items ?? []
  if (!Array.isArray(items) || items.length === 0) {
    return new Response(JSON.stringify({ error: 'No archived workspaces found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }

  // Validate requested restore_token against server-returned list
  // Prevents checkout for workspace not owned by this caller
  const target = items.find((item: { restore_token: string }) =>
    item.restore_token === requestedRestoreToken
  )

  if (!target) {
    return new Response(JSON.stringify({ error: 'Requested workspace not found in your archived workspaces' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }

  // Resolve tenant_id from restore_token server-side for Stripe subscription metadata.
  // This is internal server-to-server only -- tenant_id is never returned to the caller.
  // Required so customer.subscription.created webhook can write billing state correctly.
  const { data: tenantRow, error: tenantError } = await serviceClient
    .from('tenants')
    .select('id')
    .eq('restore_token', target.restore_token)
    .single()

  if (tenantError || !tenantRow?.id) {
    console.error('Tenant resolution error:', JSON.stringify(tenantError))
    return new Response(JSON.stringify({ error: 'Failed to resolve workspace' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
  const tenantId = tenantRow.id

  try {
    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      customer_email: customerEmail,
      line_items: [{ price: priceId, quantity: 1 }],
      subscription_data: {
        metadata: {
          tenant_id: tenantId,
        },
      },
      metadata: {
        restore_token: target.restore_token,
        user_id: userId,
      },
      success_url: appUrl + '/onboarding?restore_checkout=success',
      cancel_url: appUrl + '/onboarding?restore_checkout=canceled',
    })

    if (!session.url) {
      return new Response(JSON.stringify({ error: 'Stripe did not return a checkout URL' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    }

    console.log('restore checkout session created:', session.id, 'user:', userId, 'tenant:', tenantId)

    return new Response(JSON.stringify({ url: session.url }), {
      status: 200,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  } catch (err) {
    console.error('Stripe error:', err)
    return new Response(JSON.stringify({ error: 'Failed to create restore checkout session' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})