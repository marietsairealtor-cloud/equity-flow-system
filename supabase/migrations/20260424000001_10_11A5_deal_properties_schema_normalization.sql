-- 10.11A5: Deal Properties Schema Normalization
-- Alters deal_properties columns beds, baths, sqft from integer/numeric to text
-- Existing values are preserved via cast during migration
-- No new columns. No new tables. No RPCs added in this item.

ALTER TABLE public.deal_properties
  ALTER COLUMN beds  TYPE text USING beds::text,
  ALTER COLUMN baths TYPE text USING baths::text,
  ALTER COLUMN sqft  TYPE text USING sqft::text;