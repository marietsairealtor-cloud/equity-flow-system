-- 20260219000022_share_tokens_fix_gen_random_bytes.sql
-- 6.7 corrective: schema-qualify gen_random_bytes for CI clean-room compatibility.
-- CI environment has pgcrypto in extensions schema, not public.
-- Forward-only plain SQL. No DO blocks. No dynamic SQL. No double-dollar tags.

ALTER TABLE public.share_tokens
  ALTER COLUMN token SET DEFAULT encode(extensions.gen_random_bytes(32), 'hex');
