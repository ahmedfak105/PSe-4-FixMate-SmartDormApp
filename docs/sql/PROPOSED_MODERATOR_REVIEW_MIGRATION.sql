-- FixMate TASK #39 / F03.2: moderator report review workflow
-- Proposed ADDITIVE migration for a staging/clone Supabase project.
-- DO NOT RUN on the live project until reviewed/tested by the team.
-- The initial six-table schema gains ONE new table: report_reviews.
-- The operational maintenance_reports.status CHECK remains unchanged.
-- Prerequisites: public.profiles, public.maintenance_reports,
-- fixmate_private schema and Supabase auth.uid() already exist.
--
-- Review outcomes: valid | duplicate | inappropriate
-- Reviews are single-decision, immutable audit records.
-- Duplicate/inappropriate reports stay 'new' but are prevented from
-- staff assignment/claim by the UPDATE trigger below.
-- Review an unassigned NEW report before staff takes it.
-- All important operations are enforced inside the database, not the UI.

BEGIN;

CREATE TABLE public.report_reviews (
  report_id bigint NOT NULL PRIMARY KEY
    REFERENCES public.maintenance_reports(id) ON DELETE CASCADE,
  reviewer_id uuid NOT NULL
    REFERENCES public.profiles(id),
  outcome text NOT NULL
    CONSTRAINT report_reviews_outcome_check
    CHECK (outcome IN ('valid', 'duplicate', 'inappropriate')),
  reason text NOT NULL DEFAULT ''
    CONSTRAINT report_reviews_reason_length CHECK (char_length(reason) <= 500),
  reviewed_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX report_reviews_reviewer_idx
  ON public.report_reviews (reviewer_id, reviewed_at DESC);

ALTER TABLE public.report_reviews ENABLE ROW LEVEL SECURITY;

-- Authenticated users do not get direct write grants.
-- Only moderators/system_admins can read moderation metadata.
REVOKE ALL ON TABLE public.report_reviews FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.report_reviews TO authenticated;

CREATE POLICY "Moderators read report reviews"
ON public.report_reviews
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles AS p
    WHERE p.id = (SELECT auth.uid())
      AND p.role IN ('moderator', 'system_admin')
  )
);

-- Privileged private RPC validates role and locks the report row.
-- Lock ensures review does not race against the existing claim/assign RPC.
CREATE FUNCTION fixmate_private.review_maintenance_report(
  p_report_id bigint,
  p_outcome text,
  p_reason text DEFAULT ''
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_status text;
  v_assigned_to uuid;
  v_reason text := btrim(coalesce(p_reason, ''));
BEGIN
  IF v_actor IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = v_actor
      AND p.role IN ('moderator', 'system_admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized to review reports' USING ERRCODE = '42501';
  END IF;

  IF p_outcome IS NULL OR p_outcome NOT IN ('valid', 'duplicate', 'inappropriate') THEN
    RAISE EXCEPTION 'Invalid moderation outcome' USING ERRCODE = '22023';
  END IF;

  IF char_length(v_reason) > 500 OR
      (p_outcome IN ('duplicate', 'inappropriate') AND v_reason = '') THEN
    RAISE EXCEPTION 'A reason (1-500 chars) is required for rejected reports'
      USING ERRCODE = '22023';
  END IF;

  SELECT r.status, r.assigned_to
  INTO v_status, v_assigned_to
  FROM public.maintenance_reports r
  WHERE r.id = p_report_id
  FOR UPDATE;

  IF NOT FOUND OR v_status <> 'new' OR v_assigned_to IS NOT NULL THEN
    RETURN false;
  END IF;

  -- One decision per report; a second review is rejected gracefully.
  IF EXISTS (SELECT 1 FROM public.report_reviews rr WHERE rr.report_id = p_report_id) THEN
    RETURN false;
  END IF;

  INSERT INTO public.report_reviews (report_id, reviewer_id, outcome, reason)
  VALUES (p_report_id, v_actor, p_outcome, v_reason);

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION fixmate_private.review_maintenance_report(bigint,text,text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fixmate_private.review_maintenance_report(bigint,text,text)
  TO authenticated;

-- Thin public API wrapper. SECURITY INVOKER; the private RPC does the
-- authorized write. Never expose a service-role key in the browser.
CREATE FUNCTION public.review_maintenance_report(
  p_report_id bigint,
  p_outcome text,
  p_reason text DEFAULT ''
)
RETURNS boolean
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT fixmate_private.review_maintenance_report(p_report_id, p_outcome, p_reason);
$$;

REVOKE ALL ON FUNCTION public.review_maintenance_report(bigint,text,text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.review_maintenance_report(bigint,text,text)
  TO authenticated;

-- Ensure moderation actually impacts the maintenance workflow.
-- Existing claim/assign functions use UPDATE; this trigger prevents
-- assignment or transition to in_progress for rejected reports.
-- Valid and not-yet-reviewed reports retain their earlier claim behavior.
CREATE FUNCTION fixmate_private.block_rejected_report_work()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF (
    NEW.assigned_to IS DISTINCT FROM OLD.assigned_to
    OR NEW.status IS DISTINCT FROM OLD.status
  ) AND (NEW.assigned_to IS NOT NULL OR NEW.status = 'in_progress')
    AND EXISTS (
      SELECT 1 FROM public.report_reviews rr
      WHERE rr.report_id = NEW.id
        AND rr.outcome IN ('duplicate', 'inappropriate')
    )
  THEN
    RAISE EXCEPTION 'Report was rejected by moderation and cannot be assigned or claimed'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION fixmate_private.block_rejected_report_work()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER fixmate_block_rejected_report_work
BEFORE UPDATE OF assigned_to, status
ON public.maintenance_reports
FOR EACH ROW
EXECUTE FUNCTION fixmate_private.block_rejected_report_work();

COMMIT;

-- STAGING verification (separate review):
-- 1. Moderator: review new/unassigned reports -> valid/duplicate/inappropriate.
-- 2. Resident/staff: public.review_maintenance_report must deny writes.
-- 3. Same report: second review must return false, not silently overwrite.
-- 4. Staff claim / admin assign of duplicate/inappropriate -> rejected.
-- 5. Existing non-reviewed report claim/resolve still succeeds.
-- 6. Review report with status in_progress or assigned_to set -> false.
-- 7. Review photo access: moderator can read private report image via Storage RLS.
-- 8. Confirm RLS/grants and catalog; verify migration against fresh test DB.
