-- 20260219000018_share_tokens.sql
-- 6.7: Share token table + packet view.
-- Random non-guessable token, optional expiry, tenant-scoped.
-- UNIQUE(tenant_id, token) enables planner to use tenant_id predicate.
-- Access via SECURITY DEFINER RPCs only per CONTRACTS.md S7/S12.
-- Forward-only plain SQL. No DO blocks. No dynamic SQL. No double-dollar tags.

CREATE TABLE public.share_tokens (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid        NOT NULL,
  deal_id     uuid        NOT NULL REFERENCES public.deals(id),
  token       text        NOT NULL DEFAULT encode(extensions.gen_random_bytes(32), 'hex'),
  expires_at  timestamptz NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT share_tokens_tenant_token_unique UNIQUE (tenant_id, token)
);

ALTER TABLE public.share_tokens ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.share_tokens FROM anon, authenticated;

-- Packet view: allowlisted fields only (no internal IDs, no tenant_id)
CREATE OR REPLACE VIEW public.share_token_packet AS
  SELECT
    st.token,
    st.deal_id,
    st.expires_at,
    d.calc_version
  FROM public.share_tokens st
  JOIN public.deals d ON d.id = st.deal_id AND d.tenant_id = st.tenant_id;
