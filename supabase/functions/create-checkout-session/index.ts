// create-checkout-session/index.ts
// 10.8.9 -- Onboarding Wizard
// 10.8.12 -- Free Trial: calls claim_trial_v1() atomically to reserve trial.
//            Applies Stripe native trial_period_days = 30 when eligible.
//            Passes user_id in subscription_data.metadata for webhook confirm_trial_v1() call.
// Auth: bearer token parsed for sub (claim parsing only, not cryptographic verification).
// Ownership and context enforced server-side via RPCs called with bearer token.

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
  // Context and ownership are enforced server-side via RPCs called with this token.
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
  const { data: { user: verifiedUser }, error: userError } = await serviceClient.auth.admin.getUserById(userId)
  if (userError || !verifiedUser) {
    console.error('User lookup error:', JSON.stringify(userError))
    return new Response(JSON.stringify({ error: 'Failed to resolve user' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
  const customerEmail = verifiedUser.email ?? undefined

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

  // User-scoped client for RPC calls -- auth.uid() resolves via bearer token
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  })

  // Resolve tenant context via user profile
  const { data: profile, error: profileError } = await userClient
    .from('user_profiles')
    .select('current_tenant_id')
    .eq('id', userId)
    .single()

  if (profileError || !profile?.current_tenant_id) {
    console.error('Profile error:', JSON.stringify(profileError))
    return new Response(JSON.stringify({ error: 'No active tenant context' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }

  const tenantId = profile.current_tenant_id

  // 10.8.12: Atomically reserve trial via backend RPC.
  // claim_trial_v1() sets trial_claimed_at if eligible (one-time, 2-hour expiry).
  // Trial claim failure is fatal -- do not create checkout under uncertain trial state.
  let trialPeriodDays: number | undefined = undefined
  const { data: trialData, error: trialError } = await userClient.rpc('claim_trial_v1')

  if (trialError) {
    console.error('claim_trial_v1 error:', JSON.stringify(trialError))
    return new Response(JSON.stringify({ error: 'Failed to determine trial eligibility' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }

  if (trialData?.data?.trial_eligible === true) {
    trialPeriodDays = trialData.data.trial_period_days ?? 30
    console.log('trial reserved for user:', userId, 'trial_period_days:', trialPeriodDays)
  } else {
    console.log('trial not eligible for user:', userId)
  }

  const quantity = 1

  try {
    const sessionParams: Stripe.Checkout.SessionCreateParams = {
      mode: 'subscription',
      customer_email: customerEmail,
      line_items: [{ price: priceId, quantity }],
      subscription_data: {
        metadata: {
          tenant_id: tenantId,
          user_id: userId,
        },
        ...(trialPeriodDays ? { trial_period_days: trialPeriodDays } : {}),
      },
      success_url: appUrl + '/today?checkout=success',
      cancel_url: appUrl + '/onboarding?checkout=canceled',
    }

    const session = await stripe.checkout.sessions.create(sessionParams)

    if (!session.url) {
      return new Response(JSON.stringify({ error: 'Stripe did not return a checkout URL' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    }

    console.log('checkout session created:', session.id, 'trial:', trialPeriodDays ?? 'none')

    return new Response(JSON.stringify({ url: session.url }), {
      status: 200,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  } catch (err) {
    console.error('Stripe error:', err)
    return new Response(JSON.stringify({ error: 'Failed to create checkout session' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})