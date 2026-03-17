-- 20260317000003_10_8_1A_subscriptions_table.sql
-- Build Route 10.8.1A: Subscriptions Table (Billing Data Source)
-- Creates tenant_subscriptions table as data source for get_user_entitlements_v1 (10.8.2)
-- Stripe webhook handler is out of scope -- schema and RLS only.

-- ============================================================
-- tenant_subscriptions table
-- ============================================================

CREATE TABLE public.tenant_subscriptions (
  id                      uuid        NOT NULL DEFAULT gen_random_uuid(),
  tenant_id               uuid        NOT NULL,
  status                  text        NOT NULL,
  current_period_end      timestamptz NOT NULL,
  stripe_subscription_id  text,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tenant_subscriptions_pkey PRIMARY KEY (id),
  CONSTRAINT tenant_subscriptions_tenant_id_unique UNIQUE (tenant_id),
  CONSTRAINT tenant_subscriptions_tenant_id_fkey FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id) ON DELETE CASCADE,
  CONSTRAINT tenant_subscriptions_status_check CHECK (
    status IN ('active', 'expiring', 'expired', 'canceled')
  )
);

-- RLS ON -- default deny per GUARDRAILS §11
ALTER TABLE public.tenant_subscriptions ENABLE ROW LEVEL SECURITY;

-- CONTRACTS §12 privilege firewall -- no direct access
REVOKE ALL ON TABLE public.tenant_subscriptions FROM anon, authenticated;
