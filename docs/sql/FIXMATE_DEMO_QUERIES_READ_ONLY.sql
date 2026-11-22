-- FixMate - Lecturer demo: READ-ONLY SQL queries
-- Evidence-based table/column names extracted from the actual Supabase schema.
--
-- Use only with test data and your authorized Supabase SQL Editor access.
-- SQL Editor may run with a privileged database role and bypass ordinary RLS;
-- a successful result here does NOT prove an ordinary resident/staff can see it.
-- Every statement in this file is SELECT-only.

-- 1. Database table inventory in the public schema
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
  AND table_name IN (
    'profiles', 'maintenance_categories', 'maintenance_reports',
    'report_attachments', 'report_notes', 'report_status_history'
  )
ORDER BY table_name;

-- 2. Number of profiles in each application role
SELECT role, COUNT(*) AS user_count
FROM public.profiles
GROUP BY role
ORDER BY role;

-- 3. Maintenance categories and availability
SELECT id, name, is_active
FROM public.maintenance_categories
ORDER BY name;

-- 4. Main report view: resident, category, assigned staff, current status
SELECT
    r.id AS report_id,
    r.title,
    r.description,
    r.location,
    r.status,
    r.created_at,
    resident.full_name AS resident_name,
    category.name AS category_name,
    staff.full_name AS assigned_staff_name
FROM public.maintenance_reports AS r
JOIN public.profiles AS resident
    ON resident.id = r.resident_id
JOIN public.maintenance_categories AS category
    ON category.id = r.category_id
LEFT JOIN public.profiles AS staff
    ON staff.id = r.assigned_to
ORDER BY r.created_at DESC, r.id DESC
LIMIT 50;

-- 5. Workload summary: reports grouped by current status
SELECT status, COUNT(*) AS report_count
FROM public.maintenance_reports
GROUP BY status
ORDER BY status;

-- 6. Current staff assignments and assigned report status
SELECT
    staff.full_name AS staff_name,
    report.id AS report_id,
    report.title,
    report.status,
    report.created_at
FROM public.maintenance_reports AS report
JOIN public.profiles AS staff
    ON staff.id = report.assigned_to
ORDER BY staff.full_name, report.id;

-- 7. Timeline: recorded status transitions
SELECT
    h.report_id,
    h.old_status,
    h.new_status,
    h.changed_at,
    changed_by.full_name AS changed_by_name
FROM public.report_status_history AS h
LEFT JOIN public.profiles AS changed_by
    ON changed_by.id = h.changed_by
ORDER BY h.changed_at DESC, h.id DESC
LIMIT 50;

-- 8. Internal notes for demonstration, grouped with their report titles
SELECT
    n.report_id,
    r.title AS report_title,
    author.full_name AS author_name,
    n.content,
    n.created_at
FROM public.report_notes AS n
JOIN public.maintenance_reports AS r
    ON r.id = n.report_id
JOIN public.profiles AS author
    ON author.id = n.author_id
ORDER BY n.created_at DESC, n.id DESC
LIMIT 50;

-- 9. Attachment metadata (not a public URL; photos live in private Storage)
SELECT
    a.report_id,
    a.storage_path,
    a.created_at,
    uploader.full_name AS uploader_name
FROM public.report_attachments AS a
JOIN public.profiles AS uploader
    ON uploader.id = a.uploaded_by
ORDER BY a.created_at DESC
LIMIT 50;

-- 10. RLS-enabled flags for the six application tables
SELECT
    c.relname AS table_name,
    c.relrowsecurity AS rls_enabled,
    c.relforcerowsecurity AS rls_forced
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'p')
  AND c.relname IN (
    'profiles', 'maintenance_categories', 'maintenance_reports',
    'report_attachments', 'report_notes', 'report_status_history'
  )
ORDER BY c.relname;

-- 11. RLS enabled and underlying table privileges for Storage objects
SELECT
    c.relrowsecurity AS storage_rls_enabled,
    has_table_privilege('authenticated', c.oid, 'SELECT')
        AS authenticated_select_grant,
    has_table_privilege('authenticated', c.oid, 'INSERT')
        AS authenticated_insert_grant,
    has_table_privilege('anon', c.oid, 'SELECT')
        AS anon_select_grant
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'storage'
  AND c.relname = 'objects';

-- 12. RLS policy names for the private report photo bucket
SELECT policyname, cmd AS operation, roles
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND policyname IN (
    'fixmate_resident_read_photos',
    'fixmate_resident_upload_photos',
    'fixmate_staff_admin_read_photos'
  )
ORDER BY policyname;
