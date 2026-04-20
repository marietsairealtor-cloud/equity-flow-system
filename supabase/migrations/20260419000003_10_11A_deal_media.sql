-- 10.11A Migration 3: Create deal_media table
-- Metadata for deal photos stored in Supabase Storage
-- Actual file deletion triggered server-side via Edge Function

CREATE TABLE public.deal_media (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid        NOT NULL REFERENCES public.tenants(id),
  deal_id       uuid        NOT NULL REFERENCES public.deals(id) ON DELETE CASCADE,
  storage_path  text        NOT NULL,
  media_type    text        NOT NULL DEFAULT 'photo',
  sort_order    integer     NOT NULL DEFAULT 0,
  uploaded_at   timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  uploaded_by   uuid        NOT NULL REFERENCES auth.users(id),
  row_version   bigint      NOT NULL DEFAULT 1,
  CONSTRAINT deal_media_media_type_check CHECK (media_type IN ('photo')),
  CONSTRAINT deal_media_storage_path_unique UNIQUE (storage_path)
);

REVOKE ALL ON public.deal_media FROM anon, authenticated;

ALTER TABLE public.deal_media ENABLE ROW LEVEL SECURITY;

CREATE POLICY deal_media_tenant_isolation
  ON public.deal_media
  FOR ALL
  TO authenticated
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());