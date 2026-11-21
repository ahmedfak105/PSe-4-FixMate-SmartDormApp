-- FixMate TASK #34: PROPOSED supporting indexes for existing FK columns
-- Based on Supabase read-only pg_indexes and Performance Advisor inspection
-- on 2026-11-22. 9 foreign keys lacked leading-column indexes.
--
-- THIS IS NOT A DEPLOYED MIGRATION. Review and apply in a staging/clone DB,
-- ideally as part of a reviewed, ordered baseline migration set.
-- All indexes here are BTREE and non-unique. They do not change constraints,
-- RLS, role grants, business data, or application logic.
--
-- IMPORTANT: CREATE INDEX may temporarily lock writers. For large tables
-- evaluate CREATE INDEX CONCURRENTLY in standalone statements instead.
-- The existing FixMate tables currently contain only small test datasets.
-- Avoid altering live production solely to clear informational lints.

CREATE INDEX IF NOT EXISTS maintenance_reports_resident_id_idx
  ON public.maintenance_reports (resident_id);

CREATE INDEX IF NOT EXISTS maintenance_reports_category_id_idx
  ON public.maintenance_reports (category_id);

CREATE INDEX IF NOT EXISTS maintenance_reports_assigned_to_idx
  ON public.maintenance_reports (assigned_to);

CREATE INDEX IF NOT EXISTS report_attachments_report_id_idx
  ON public.report_attachments (report_id);

CREATE INDEX IF NOT EXISTS report_attachments_uploaded_by_idx
  ON public.report_attachments (uploaded_by);

CREATE INDEX IF NOT EXISTS report_notes_report_id_idx
  ON public.report_notes (report_id);

CREATE INDEX IF NOT EXISTS report_notes_author_id_idx
  ON public.report_notes (author_id);

CREATE INDEX IF NOT EXISTS report_status_history_report_id_idx
  ON public.report_status_history (report_id);

CREATE INDEX IF NOT EXISTS report_status_history_changed_by_idx
  ON public.report_status_history (changed_by);

-- STAGING VERIFICATION (run separately after deployment):
-- SELECT schemaname, tablename, indexname, indexdef
-- FROM pg_indexes
-- WHERE schemaname='public' AND indexname LIKE '%_idx'
-- ORDER BY tablename, indexname;
--
-- Then run Supabase Performance Advisor again; check that missing FK index
-- findings for these columns have cleared. Do not assume all performance
-- findings are resolved; RLS policy optimization is a separate review.
--
-- Observed baseline: Only PK/UNIQUE indexes existed in these tables:
-- profiles_pkey, maintenance_categories_pkey/name_key,
-- maintenance_reports_pkey, report_attachments_pkey/storage_path_unique,
-- report_notes_pkey, report_status_history_pkey.
