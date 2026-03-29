// stripe-webhook/index.ts
// 10.8.8C -- Stripe Billing Foundation
// Handles Stripe webhook events in test mode.
// Writes/updates tenant_subscriptions on subscription lifecycle events.

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

Deno.serve(async (req: Request) => {
  const signature = req.headers.get('stripe-signature')
  const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? ''
  const body = await req.text()

  let event: Stripe.Event

  try {
    event = await stripe.webhooks.constructEventAsync(body, signature ?? '', webhookSecret)
  } catch (err) {
    console.error('Webhook signature verification failed:', err)
    return new Response(JSON.stringify({ error: 'Invalid signature' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  console.log('Stripe event received:', event.type, event.id)

  try {
    switch (event.type) {
      case 'customer.subscription.created':
      case 'customer.subscription.updated': {
        const sub = event.data.object as Stripe.Subscription
        const tenantId = sub.metadata?.tenant_id

        if (!tenantId) {
          console.error('No tenant_id in subscription metadata:', sub.id)
          break
        }

        const status = resolveStatus(sub)

        // current_period_end may be on the subscription or on the first item
        const periodEnd = sub.current_period_end
          ?? (sub as any).items?.data?.[0]?.current_period_end
          ?? null

        const currentPeriodEnd = periodEnd
          ? new Date(periodEnd * 1000).toISOString()
          : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()

        const { error } = await supabase
          .from('tenant_subscriptions')
          .upsert({
            tenant_id: tenantId,
            stripe_subscription_id: sub.id,
            status,
            current_period_end: currentPeriodEnd,
            updated_at: new Date().toISOString(),
            row_version: 1,
          }, { onConflict: 'tenant_id' })

        if (error) {
          console.error('Failed to upsert tenant_subscriptions:', error)
          return new Response(JSON.stringify({ error: 'DB write failed' }), {
            status: 500,
            headers: { 'Content-Type': 'application/json' },
          })
        }

        console.log('tenant_subscriptions updated for tenant:', tenantId, 'status:', status)
        break
      }

      case 'customer.subscription.deleted': {
        const sub = event.data.object as Stripe.Subscription
        const tenantId = sub.metadata?.tenant_id

        if (!tenantId) {
          console.error('No tenant_id in subscription metadata:', sub.id)
          break
        }

        const { error } = await supabase
          .from('tenant_subscriptions')
          .update({
            status: 'canceled',
            updated_at: new Date().toISOString(),
          })
          .eq('tenant_id', tenantId)

        if (error) {
          console.error('Failed to cancel tenant_subscriptions:', error)
          return new Response(JSON.stringify({ error: 'DB write failed' }), {
            status: 500,
            headers: { 'Content-Type': 'application/json' },
          })
        }

        console.log('tenant_subscriptions canceled for tenant:', tenantId)
        break
      }

      default:
        console.log('Unhandled event type:', event.type)
    }
  } catch (err) {
    console.error('Error processing event:', err)
    return new Response(JSON.stringify({ error: 'Processing failed' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  return new Response(JSON.stringify({ received: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
})

function resolveStatus(sub: Stripe.Subscription): string {
  if (sub.status === 'canceled') return 'canceled'

  const periodEnd = sub.current_period_end
    ?? (sub as any).items?.data?.[0]?.current_period_end
    ?? null

  if (!periodEnd) return 'active'

  const now = Math.floor(Date.now() / 1000)
  const daysRemaining = (periodEnd - now) / 86400

  if (sub.status === 'active' && daysRemaining > 7) return 'active'
  if (sub.status === 'active' && daysRemaining <= 7) return 'expiring'
  return 'expired'
}