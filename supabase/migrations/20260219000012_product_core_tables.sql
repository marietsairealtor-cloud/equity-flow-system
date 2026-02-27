-- 20260219000012_product_core_tables.sql
-- 6.6: Product core tables: deal_inputs, deal_outputs, calc_versions.
-- Hardens deals: row_version NOT NULL DEFAULT 1, calc_version NOT NULL DEFAULT 1.
-- Access via SECURITY DEFINER RPCs only per CONTRACTS.md S7+S12.
-- No direct GRANTs to anon or authenticated on core tables.
-- Forward-only plain SQL. No DO blocks. No dynamic SQL. No double-dollar tags.

-- Harden existing deals columns
ALTER TABLE public.deals ALTER COLUMN row_version SET NOT NULL;
ALTER TABLE public.deals ALTER COLUMN row_version SET DEFAULT 1;
ALTER TABLE public.deals ALTER COLUMN calc_version SET NOT NULL;
ALTER TABLE public.deals ALTER COLUMN calc_version SET DEFAULT 1;

-- calc_versions: reference registry of calc engine versions
CREATE TABLE public.calc_versions (
  id           integer      PRIMARY KEY,
  label        text         NOT NULL,
  released_at  timestamptz  NOT NULL DEFAULT now()
);

-- deal_inputs: assumption snapshots bound to a deal + calc_version
CREATE TABLE public.deal_inputs (
  id            uuid        PRIMARY KEY,
  tenant_id     uuid        NOT NULL,
  deal_id       uuid        NOT NULL REFERENCES public.deals(id),
  calc_version  integer     NOT NULL DEFAULT 1,
  row_version   bigint      NOT NULL DEFAULT 1,
  assumptions   jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- deal_outputs: computed results bound to a deal + calc_version
CREATE TABLE public.deal_outputs (
  id            uuid        PRIMARY KEY,
  tenant_id     uuid        NOT NULL,
  deal_id       uuid        NOT NULL REFERENCES public.deals(id),
  calc_version  integer     NOT NULL DEFAULT 1,
  row_version   bigint      NOT NULL DEFAULT 1,
  outputs       jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- RLS ON, default deny — no policies, no direct grants
-- Access is exclusively via allowlisted SECURITY DEFINER RPCs per CONTRACTS.md S7+S12
ALTER TABLE public.calc_versions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deal_inputs    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deal_outputs   ENABLE ROW LEVEL SECURITY;

-- Explicit REVOKE ALL per CONTRACTS.md S12 (migration-rls-colocation gate)
REVOKE ALL ON TABLE public.calc_versions FROM anon, authenticated;
REVOKE ALL ON TABLE public.deal_inputs FROM anon, authenticated;
REVOKE ALL ON TABLE public.deal_outputs FROM anon, authenticated;
