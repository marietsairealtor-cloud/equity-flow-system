import Stripe from 'https://esm.sh/stripe@13.11.0'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
})

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
)

const SEAT_PRICE_ID = Deno.env.get('STRIPE_PRICE_ID') ?? ''

Deno.serve(async (req: Request) => {
  try {
    const payload = await req.json()
    const record = payload.record

    if (!record?.tenant_id) {
      console.error('No tenant_id in payload')
      return new Response('no tenant_id', { status: 200 })
    }

    const tenantId = record.tenant_id
    console.log('Processing tenant:', tenantId)
    console.log('SEAT_PRICE_ID:', SEAT_PRICE_ID)

    // Count ALL active tenant_memberships for this tenant
    const { count, error: countError } = await supabase
      .from('tenant_memberships')
      .select('*', { count: 'exact', head: true })
      .eq('tenant_id', tenantId)

    if (countError) {
      console.error('Member count error:', countError)
      return new Response('count error', { status: 200 })
    }

    const seatCount = count ?? 0
    console.log('Seat count:', seatCount)

    // Get Stripe subscription ID for this tenant
    const { data: sub, error: subError } = await supabase
      .from('tenant_subscriptions')
      .select('stripe_subscription_id')
      .eq('tenant_id', tenantId)
      .single()

    if (subError || !sub?.stripe_subscription_id) {
      console.log('No subscription found for tenant — no-op:', tenantId)
      return new Response('no subscription', { status: 200 })
    }

    console.log('Stripe subscription ID:', sub.stripe_subscription_id)

    // Retrieve subscription and log all items
    const subscription = await stripe.subscriptions.retrieve(sub.stripe_subscription_id)
    console.log('Subscription items:', JSON.stringify(subscription.items.data.map(i => ({ id: i.id, price: i.price.id }))))
    console.log('Looking for SEAT_PRICE_ID:', SEAT_PRICE_ID)

    const seatItem = subscription.items.data.find(
      (item) => item.price.id === SEAT_PRICE_ID
    )

    if (!seatItem) {
      console.log('No seat price item found — no-op:', sub.stripe_subscription_id)
      return new Response('no seat item', { status: 200 })
    }

    console.log('Found seat item:', seatItem.id)

    // Update Stripe subscription quantity — absolute recomputation, idempotent
    await stripe.subscriptionItems.update(seatItem.id, {
      quantity: seatCount,
    })

    console.log(`Seat sync complete: tenant=${tenantId} seats=${seatCount} item=${seatItem.id}`)
    return new Response('ok', { status: 200 })

  } catch (err) {
    console.error('sync-seat-count error:', err)
    return new Response('error', { status: 200 })
  }
})