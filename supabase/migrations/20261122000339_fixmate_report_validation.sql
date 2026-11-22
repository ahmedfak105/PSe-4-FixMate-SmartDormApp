-- FixMate TASK #36 — proposed backend report-input validation.
-- STAGING ONLY. NOT deployed to the live Supabase project.
-- Apply only AFTER the verified six-table baseline on a clean test database,
-- and AFTER reviewing existing reports for compatibility.
--
-- Inspection 2026-11-22: all five live test reports had nonblank title,
-- description, location, title length <=120, and active categories.
-- This proposal aligns backend checks with required Flutter form fields.
--
-- Explicitly not changing the existing role rules/status transition logic.
BEGIN;

ALTER TABLE public.maintenance_reports
  ADD CONSTRAINT fixmate_report_title_nonblank
    CHECK (char_length(btrim(title)) > 0 AND char_length(title) <= 120),
  ADD CONSTRAINT fixmate_report_description_nonblank
    CHECK (char_length(btrim(description)) > 0),
  ADD CONSTRAINT fixmate_report_location_nonblank
    CHECK (location IS NOT NULL AND char_length(btrim(location)) > 0);

-- The original RLS insert policy already restricts inserts to the owning
-- Resident with status new and no assignment. Also require an ACTIVE category
-- at insertion time, so clients cannot submit archived category IDs.
ALTER POLICY "Residents create reports"
ON public.maintenance_reports
WITH CHECK (
  resident_id = (SELECT auth.uid())
  AND status = 'new'
  AND assigned_to IS NULL
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = (SELECT auth.uid())
      AND p.role = 'resident'
  )
  AND EXISTS (
    SELECT 1 FROM public.maintenance_categories c
    WHERE c.id = category_id AND c.is_active = true
  )
);

COMMIT;

-- REQUIRED STAGING TESTS (run as authenticated Resident, not only SQL Editor):
-- 1. Valid report with active category succeeds, resident_id is auth.uid().
-- 2. '  ' title, description or location rejected by CHECK constraints.
-- 3. Title >120 chars rejected; exactly 120 chars accepted.
-- 4. Inactive category rejected by RLS; valid active category accepted.
-- 5. Status in_progress or non-null assigned_to rejected on insert.
-- 6. Maintenance Staff/Moderator/Admin cannot create a Resident report.
-- 7. Existing report read/claim/resolve and image upload still work.
-- 8. Re-run Supabase Security Advisor; confirm client errors are readable.
--
-- This migration adds stricter checks but does not implement an upload-size
-- or MIME check (those are independently enforced by Storage bucket settings).
