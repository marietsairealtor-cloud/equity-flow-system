// stripe-webhook/index.ts
// 10.8.8C -- Stripe Billing Foundation
// 10.8.12 -- Free Trial: calls confirm_trial_v1() when subscription created with trialing status.
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
        const userId = sub.metadata?.user_id

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
          console.error('upsert_subscription_v1 transport error:', error)
          return new Response(JSON.stringify({ error: 'RPC call failed' }), {
            status: 500,
            headers: { 'Content-Type': 'application/json' },
          })
        }
        if (!data?.ok) {
          console.error('upsert_subscription_v1 envelope failure:', JSON.stringify(data))
          return new Response(JSON.stringify({ error: 'upsert_subscription_v1 returned failure', code: data?.code }), {
            status: 500,
            headers: { 'Content-Type': 'application/json' },
          })
        }

        console.log('upsert_subscription_v1 result:', JSON.stringify(data))

        // 10.8.12: Confirm trial usage after subscription created in trialing state.
        // Only fires on subscription created event with trialing status and user_id in metadata.
        if (
          event.type === 'customer.subscription.created' &&
          status === 'trialing' &&
          userId &&
          tenantId
        ) {
          const { data: confirmData, error: confirmError } = await supabase.rpc('confirm_trial_v1', {
            p_user_id:   userId,
            p_tenant_id: tenantId,
          })

          if (confirmError) {
            console.error('confirm_trial_v1 transport error:', JSON.stringify(confirmError))
            return new Response(JSON.stringify({ error: 'Trial confirmation failed' }), {
              status: 500,
              headers: { 'Content-Type': 'application/json' },
            })
          }
          if (!confirmData?.ok) {
            console.error('confirm_trial_v1 envelope failure:', JSON.stringify(confirmData))
            return new Response(JSON.stringify({ error: 'confirm_trial_v1 returned failure', code: confirmData?.code }), {
              status: 500,
              headers: { 'Content-Type': 'application/json' },
            })
          }
          console.log('confirm_trial_v1 result:', JSON.stringify(confirmData))
        }

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
          console.error('upsert_subscription_v1 transport error on delete:', error)
          return new Response(JSON.stringify({ error: 'RPC call failed' }), {
            status: 500,
            headers: { 'Content-Type': 'application/json' },
          })
        }
        if (!data?.ok) {
          console.error('upsert_subscription_v1 envelope failure on delete:', JSON.stringify(data))
          return new Response(JSON.stringify({ error: 'upsert_subscription_v1 returned failure', code: data?.code }), {
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
  // Persist raw Stripe subscription status only.
  // Status derivation (expiring, access/routing) is handled in get_user_entitlements_v1().
  // Unknown statuses are logged and mapped to expired (safe fallback -- restricts access).
  switch (sub.status) {
    case 'trialing':            return 'trialing'
    case 'active':              return 'active'
    case 'canceled':            return 'canceled'
    case 'past_due':
    case 'unpaid':
    case 'incomplete_expired':  return 'expired'
    default:
      console.error('resolveStatus: unknown Stripe subscription status:', sub.status)
      return 'expired'
  }
}