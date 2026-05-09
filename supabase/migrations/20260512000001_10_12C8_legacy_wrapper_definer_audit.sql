-- 10.12C8 corrective: legacy mark_submission_reviewed_v1(uuid, text) must reference
-- current_tenant_id() in prosrc for scripts/ci_definer_safety_audit.ps1 (Build Route 6.2).

CREATE OR REPLACE FUNCTION public.mark_submission_reviewed_v1(
  p_submission_id uuid,
  p_outcome       text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $legacy$
BEGIN
  PERFORM public.current_tenant_id();
  RETURN public.mark_submission_reviewed_v1(p_outcome, p_submission_id, NULL::uuid);
END;
$legacy$;

ALTER FUNCTION public.mark_submission_reviewed_v1(uuid, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.mark_submission_reviewed_v1(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_submission_reviewed_v1(uuid, text) TO authenticated;
