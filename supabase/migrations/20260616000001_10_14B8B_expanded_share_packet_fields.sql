-- 10.14B8B -- Dispo Backend -- Expanded Share Packet Fields
-- Migration 1 of 3: Add new dispo_* columns to public.deals
-- All new columns are NULL by default. Backward compatible.

ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS dispo_headline       text NULL,
  ADD COLUMN IF NOT EXISTS dispo_tagline        text NULL,
  ADD COLUMN IF NOT EXISTS dispo_offer_deadline timestamptz NULL,
  ADD COLUMN IF NOT EXISTS dispo_walkthrough    text NULL,
  ADD COLUMN IF NOT EXISTS dispo_features       text NULL,
  ADD COLUMN IF NOT EXISTS dispo_contact_name   text NULL,
  ADD COLUMN IF NOT EXISTS dispo_contact_phone  text NULL;
