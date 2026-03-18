-- 20260318000004_10_8_3B_tenant_subscriptions_row_version.sql
-- Build Route 10.8.3B: Add row_version to tenant_subscriptions
-- Closes audit finding B9-F04 identified in 10.8.3A audit.
-- tenant_subscriptions is mutable (status, current_period_end updated
-- by billing events) -- GUARDRAILS S8 requires row_version.
-- Forward-only plain SQL. No DO blocks. No dynamic SQL.

ALTER TABLE public.tenant_subscriptions
  ADD COLUMN row_version bigint NOT NULL DEFAULT 1;
