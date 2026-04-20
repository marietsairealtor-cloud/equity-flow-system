-- 10.11A Migration 2: Create deal_properties table

CREATE TABLE public.deal_properties (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid        NOT NULL REFERENCES public.tenants(id),
  deal_id          uuid        NOT NULL REFERENCES public.deals(id) ON DELETE CASCADE,
  row_version      bigint      NOT NULL DEFAULT 1,
  property_type    text        NULL,
  beds             integer     NULL,
  baths            numeric     NULL,
  sqft             integer     NULL,
  lot_size         text        NULL,
  year_built       integer     NULL,
  occupancy        text        NULL,
  deficiency_tags  text[]      NULL,
  condition_notes  text        NULL,
  repair_estimate  numeric     NULL,
  garage_parking   text        NULL,
  basement_type    text        NULL,
  foundation_type  text        NULL,
  roof_age         integer     NULL,
  furnace_age      integer     NULL,
  ac_age           integer     NULL,
  heating_type     text        NULL,
  cooling_type     text        NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT deal_properties_deal_id_unique UNIQUE (deal_id)
);

REVOKE ALL ON public.deal_properties FROM anon, authenticated;

ALTER TABLE public.deal_properties ENABLE ROW LEVEL SECURITY;

CREATE POLICY deal_properties_tenant_isolation
  ON public.deal_properties
  FOR ALL
  TO authenticated
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());