-- 10.8.4 corrective: drop and recreate get_deal_health_color without SECURITY DEFINER.
-- Cloud had stale version with SECURITY DEFINER from prior push.
-- This migration strips it cleanly per definer-safety-audit requirements.

DROP FUNCTION IF EXISTS public.get_deal_health_color(TEXT, TIMESTAMPTZ);

CREATE FUNCTION public.get_deal_health_color(
  p_stage      TEXT,
  p_updated_at TIMESTAMPTZ
)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $fn$
  SELECT CASE
    WHEN p_updated_at IS NULL THEN 'yellow'
    WHEN p_stage = 'New'                 AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 3        THEN 'red'
    WHEN p_stage = 'New'                 AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 3 * 0.7  THEN 'yellow'
    WHEN p_stage = 'Analyzing'           AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7        THEN 'red'
    WHEN p_stage = 'Analyzing'           AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7 * 0.7  THEN 'yellow'
    WHEN p_stage = 'Offer Sent'          AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 5        THEN 'red'
    WHEN p_stage = 'Offer Sent'          AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 5 * 0.7  THEN 'yellow'
    WHEN p_stage = 'Under Contract (UC)' AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 14       THEN 'red'
    WHEN p_stage = 'Under Contract (UC)' AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 14 * 0.7 THEN 'yellow'
    WHEN p_stage = 'Dispo'               AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7        THEN 'red'
    WHEN p_stage = 'Dispo'               AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7 * 0.7  THEN 'yellow'
    ELSE 'green'
  END
$fn$;

REVOKE ALL ON FUNCTION public.get_deal_health_color(TEXT, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;