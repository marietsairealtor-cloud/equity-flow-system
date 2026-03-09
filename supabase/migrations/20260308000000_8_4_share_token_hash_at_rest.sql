-- 8.4: Share Token Hash-at-Rest
-- Converts share_tokens from storing raw tokens to storing SHA-256 hashes.
-- Raw tokens are never persisted after this migration.

-- Step 1: Add token_hash column
ALTER TABLE public.share_tokens ADD COLUMN token_hash bytea;

-- Step 2: Populate token_hash from existing raw tokens
UPDATE public.share_tokens
SET token_hash = extensions.digest(token, 'sha256')
WHERE token IS NOT NULL;

-- Step 3: Make token_hash NOT NULL
ALTER TABLE public.share_tokens ALTER COLUMN token_hash SET NOT NULL;

-- Step 4: Drop the unique constraint on (tenant_id, token)
ALTER TABLE public.share_tokens DROP CONSTRAINT share_tokens_tenant_token_unique;

-- Step 5: Drop raw token column
-- Drop view first (depends on token column)
DROP VIEW IF EXISTS public.share_token_packet;

ALTER TABLE public.share_tokens DROP COLUMN token;

-- Step 6: Add unique index on token_hash
CREATE UNIQUE INDEX share_tokens_token_hash_unique ON public.share_tokens (token_hash);

-- Step 7: Revoke direct access (maintain privilege firewall)
REVOKE ALL ON public.share_tokens FROM authenticated;
REVOKE ALL ON public.share_tokens FROM anon;