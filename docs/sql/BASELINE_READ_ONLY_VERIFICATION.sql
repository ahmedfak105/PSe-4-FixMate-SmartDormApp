-- FixMate — READ-ONLY post-restore verification for a fresh Supabase clone.
-- Captured baseline 2026-11-22: 6 tables, 8 app functions,
-- 13 public RLS policies, 3 FixMate Storage policies, 8 categories.
-- No inserts, updates, deletes, settings changes or DDL here.
--
-- IMPORTANT: Do not compare user/report counts with production; staging
-- must use NEW test users and reports rather than a copy of private data.

-- 1. Six public application tables; all have RLS enabled.
SELECT c.relname AS app_table, c.relrowsecurity AS rls_enabled
FROM pg_class AS c JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname='public' AND c.relkind='r' AND c.relname IN (
  'profiles','maintenance_categories','maintenance_reports',
  'report_attachments','report_notes','report_status_history')
ORDER BY c.relname;

-- 2. Role representation and report-state constraints.
SELECT conrelid::regclass AS app_table, conname AS constraint_name,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid IN (
  'public.profiles'::regclass, 'public.maintenance_reports'::regclass,
  'public.report_status_history'::regclass)
  AND contype='c'
ORDER BY app_table::text, conname;

-- 3. Application function signatures and SECURITY DEFINER status.
SELECT n.nspname AS function_schema, p.proname AS function_name,
       pg_get_function_identity_arguments(p.oid) AS arguments,
       p.prosecdef AS security_definer
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid=p.pronamespace
WHERE (n.nspname='fixmate_private'
  AND p.proname IN ('current_user_is_system_admin',
                   'claim_maintenance_report','resolve_maintenance_report',
                   'assign_maintenance_report'))
   OR (n.nspname='public'
  AND p.proname IN ('claim_maintenance_report','resolve_maintenance_report',
                   'assign_maintenance_report'))
   OR (n.nspname='private' AND p.proname='handle_new_user')
ORDER BY n.nspname, p.proname;

-- 4. Public and Storage policies. Expect 13 + 3.
SELECT schemaname, tablename, policyname, cmd, roles
FROM pg_policies
WHERE (schemaname='public' AND tablename IN (
  'profiles','maintenance_categories','maintenance_reports',
  'report_attachments','report_notes','report_status_history'))
OR (schemaname='storage' AND tablename='objects'
    AND policyname LIKE 'fixmate_%')
ORDER BY schemaname,tablename,policyname;

-- 5. Live reference roles: authenticated may edit allowed profile fields
-- but NOT directly update role or INSERT a profile.
SELECT
  has_table_privilege('authenticated','public.profiles','INSERT')
    AS authenticated_can_insert_profile,
  has_column_privilege('authenticated','public.profiles','role','UPDATE')
    AS authenticated_can_update_role,
  has_column_privilege('authenticated','public.profiles','full_name','UPDATE')
    AS authenticated_can_update_full_name,
  has_schema_privilege('authenticated','fixmate_private','USAGE')
    AS authenticated_can_use_fixmate_rpc_schema;

-- 6. Auth user creation trigger.
SELECT tg.tgname, pg_get_triggerdef(tg.oid,true) AS definition
FROM pg_trigger AS tg
WHERE tg.tgrelid='auth.users'::regclass AND NOT tg.tgisinternal;

-- 7. Private photo bucket (do not list or copy private files).
SELECT id,name,public,file_size_limit,allowed_mime_types
FROM storage.buckets WHERE id='report-photos';

-- 8. Category seed: expected 8 with same names.
SELECT name,is_active FROM public.maintenance_categories ORDER BY name;

-- 9. Supporting unique storage path index.
SELECT indexname,indexdef FROM pg_indexes
WHERE schemaname='public' AND tablename='report_attachments'
  AND indexname='report_attachments_storage_path_unique';

-- 10. Test acceptance still REQUIRES role-authenticated API requests
-- (resident, staff, moderator, admin); SQL Editor alone cannot prove RLS.
