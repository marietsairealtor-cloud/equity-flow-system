// create-checkout-session/index.ts
// 10.8.9 -- Onboarding Wizard
// Verifies user JWT via service role client getUser(token).
// Price and quantity are backend-controlled. No frontend input accepted.

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

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing authorization header' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }

  const token = authHeader.replace('Bearer ', '')

  const { data: { user }, error: authError } = await serviceClient.auth.getUser(token)

  if (authError || !user) {
    console.error('Auth error:', JSON.stringify(authError))
    return new Response(JSON.stringify({ error: 'Invalid or expired token', detail: authError?.message }), {
      status: 401,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }

  const { data: profile, error: profileError } = await serviceClient
    .from('user_profiles')
    .select('current_tenant_id')
    .eq('id', user.id)
    .single()

  if (profileError || !profile?.current_tenant_id) {
    console.error('Profile error:', JSON.stringify(profileError))
    return new Response(JSON.stringify({ error: 'No active tenant context' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }

  const tenantId = profile.current_tenant_id

  const priceId = Deno.env.get('STRIPE_PRICE_ID')
  if (!priceId) {
    return new Response(JSON.stringify({ error: 'Stripe price not configured' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }

  const appUrl = Deno.env.get('APP_URL')
  if (!appUrl) {
    return new Response(JSON.stringify({ error: 'APP_URL not configured' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }

  const quantity = 1

  try {
    const session = await stripe.checkout.sessions.create({
    mode: 'subscription',
    customer_email: user.email ?? undefined,
    line_items: [{ price: priceId, quantity }],
    subscription_data: { metadata: { tenant_id: tenantId } },
    success_url: appUrl + '/today?checkout=success',
    cancel_url: appUrl + '/onboarding?checkout=canceled',
  })

    if (!session.url) {
      return new Response(JSON.stringify({ error: 'Stripe did not return a checkout URL' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    }

    console.log('checkout session created:', session.id)

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