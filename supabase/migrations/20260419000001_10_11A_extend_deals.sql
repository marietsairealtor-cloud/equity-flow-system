-- 10.11A Migration 1: Extend deals table
-- Normalizes stage values, updates constraint, adds new columns

-- Step 1: Drop existing stage check constraint
ALTER TABLE public.deals
  DROP CONSTRAINT IF EXISTS deals_stage_check;

-- Step 2: Update stage default to normalized value
ALTER TABLE public.deals
  ALTER COLUMN stage SET DEFAULT 'new';

-- Step 3: Add new check constraint with locked canonical stage values
ALTER TABLE public.deals
  ADD CONSTRAINT deals_stage_check CHECK (
    stage IN (
      'new',
      'analyzing',
      'offer_sent',
      'under_contract',
      'dispo',
      'tc',
      'closed',
      'dead'
    )
  );

-- Step 4: Add new columns
ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS created_at          timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS address             text        NULL,
  ADD COLUMN IF NOT EXISTS assignee_user_id    uuid        NULL REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS seller_name         text        NULL,
  ADD COLUMN IF NOT EXISTS seller_phone        text        NULL,
  ADD COLUMN IF NOT EXISTS seller_email        text        NULL,
  ADD COLUMN IF NOT EXISTS seller_pain         text        NULL,
  ADD COLUMN IF NOT EXISTS seller_timeline     text        NULL,
  ADD COLUMN IF NOT EXISTS seller_notes        text        NULL,
  ADD COLUMN IF NOT EXISTS next_action         text        NULL,
  ADD COLUMN IF NOT EXISTS next_action_due     timestamptz NULL,
  ADD COLUMN IF NOT EXISTS dead_reason         text        NULL;