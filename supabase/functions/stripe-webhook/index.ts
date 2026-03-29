// stripe-webhook/index.ts
// 10.8.8C -- Stripe Billing Foundation
// Handles Stripe webhook events in test mode.
// Writes tenant_subscriptions via upsert_subscription_v1 RPC only.

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

        const periodEnd = sub.current_period_end
          ?? (sub as any).items?.data?.[0]?.current_period_end
          ?? null

        const currentPeriodEnd = periodEnd
          ? new Date(periodEnd * 1000).toISOString()
          : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()

        const { data, error } = await supabase.rpc('upsert_subscription_v1', {
          p_tenant_id:              tenantId,
          p_stripe_subscription_id: sub.id,
          p_status:                 status,
          p_current_period_end:     currentPeriodEnd,
        })

        if (error) {
          console.error('upsert_subscription_v1 error:', error)
          return new Response(JSON.stringify({ error: 'RPC call failed' }), {
            status: 500,
            headers: { 'Content-Type': 'application/json' },
          })
        }

        console.log('upsert_subscription_v1 result:', JSON.stringify(data))
        break
      }

      case 'customer.subscription.deleted': {
        const sub = event.data.object as Stripe.Subscription
        const tenantId = sub.metadata?.tenant_id

        if (!tenantId) {
          console.error('No tenant_id in subscription metadata:', sub.id)
          break
        }

        const periodEnd = sub.current_period_end
          ?? (sub as any).items?.data?.[0]?.current_period_end
          ?? null

        const currentPeriodEnd = periodEnd
          ? new Date(periodEnd * 1000).toISOString()
          : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()

        const { data, error } = await supabase.rpc('upsert_subscription_v1', {
          p_tenant_id:              tenantId,
          p_stripe_subscription_id: sub.id,
          p_status:                 'canceled',
          p_current_period_end:     currentPeriodEnd,
        })

        if (error) {
          console.error('upsert_subscription_v1 error on delete:', error)
          return new Response(JSON.stringify({ error: 'RPC call failed' }), {
            status: 500,
            headers: { 'Content-Type': 'application/json' },
          })
        }

        console.log('upsert_subscription_v1 canceled result:', JSON.stringify(data))
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