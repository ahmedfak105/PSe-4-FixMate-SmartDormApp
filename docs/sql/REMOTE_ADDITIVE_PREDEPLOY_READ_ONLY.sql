-- FixMate TASK #36/#39 — READ-ONLY preflight for EXISTING Supabase projects
-- Run only as a review/query (never as a destructive migration).
-- This records compatibility and detects whether the proposed changes exist.
-- 2026-11-22 baseline inventory: five sample reports, zero invalid rows,
-- zero inactive category references, review table/RPC/trigger absent.
--
-- A passing result DOES NOT authorize deploying migrations to production.
SELECT
  current_database() AS database_name,
  (SELECT count(*) FROM public.maintenance_reports) AS report_rows,
  (SELECT count(*) FROM public.maintenance_reports r
    WHERE btrim(r.title) = '' OR btrim(r.description) = ''
       OR r.location IS NULL OR btrim(r.location) = ''
       OR char_length(r.title) > 120) AS report_fields_incompatible,
  (SELECT count(*) FROM public.maintenance_reports r
    WHERE NOT EXISTS (
      SELECT 1 FROM public.maintenance_categories c
      WHERE c.id = r.category_id AND c.is_active
    )) AS archived_category_references,
  (SELECT count(*) FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'maintenance_reports'
      AND policyname = 'Residents create reports') AS resident_insert_policies,
  (SELECT count(*) FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'report_reviews')
    AS existing_moderation_tables,
  (SELECT count(*) FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'review_maintenance_report')
    AS existing_public_review_rpcs,
  (SELECT count(*) FROM pg_trigger
    WHERE tgrelid = 'public.maintenance_reports'::regclass
      AND tgname = 'fixmate_block_rejected_report_work'
      AND NOT tgisinternal) AS existing_moderation_guards;

-- Existing constraints and their definitions. The proposed three checks
-- should be absent before an additive first-time migration; identify name
-- collisions and unexpected customized constraints.
SELECT c.conname, pg_get_constraintdef(c.oid) AS definition
FROM pg_constraint c
WHERE c.conrelid = 'public.maintenance_reports'::regclass
ORDER BY c.conname;

-- Existing INSERT policy (capture its USING/WITH CHECK rules exactly).
SELECT policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'maintenance_reports'
  AND cmd = 'INSERT'
ORDER BY policyname;

-- Check for reserved objects/overlaps and indexes before applying TASK #39.
SELECT n.nspname AS schema_name, p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS function_arguments
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public', 'fixmate_private')
  AND p.proname IN ('review_maintenance_report', 'block_rejected_report_work')
ORDER BY n.nspname, p.proname;

-- No live table DML, Auth user modifications, Storage operations or grants.
