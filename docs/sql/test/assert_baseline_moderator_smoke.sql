-- Disposable PostgreSQL smoke tests for the catalog-derived FixMate
-- baseline and PROPOSED Moderator migration. These use synthetic UUIDs.
-- Must run ONLY after prepare_postgres_smoke.sql, baseline, categories,
-- and proposed moderator migration in an isolated DB.
-- No test fixture or credential belongs to production.

-- Baseline inventory counts and constraint/policy presence.
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n
  FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace
  WHERE s.nspname='public' AND c.relkind='r'
    AND c.relname IN ('profiles','maintenance_categories',
      'maintenance_reports','report_attachments','report_notes',
      'report_status_history');
  IF n<>7 THEN
    -- The six baseline tables + the new report_reviews table.
    RAISE EXCEPTION 'Expected seven tables (baseline+moderator), found %',n;
  END IF;
  SELECT count(*) INTO n FROM pg_policies
  WHERE schemaname='public'
    AND tablename IN ('profiles','maintenance_categories',
       'maintenance_reports','report_attachments','report_notes',
       'report_status_history','report_reviews');
  IF n<>14 THEN RAISE EXCEPTION 'Expected 14 public policies, got %',n; END IF;
  SELECT count(*) INTO n FROM pg_policies
    WHERE schemaname='storage' AND tablename='objects'
      AND policyname LIKE 'fixmate_%';
  IF n<>3 THEN RAISE EXCEPTION 'Expected three Storage policies, got %',n; END IF;
  SELECT count(*) INTO n FROM public.maintenance_categories;
  IF n<>8 THEN RAISE EXCEPTION 'Expected eight categories, got %',n; END IF;
  IF (SELECT public FROM storage.buckets WHERE id='report-photos') IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'Photos bucket must remain private';
  END IF;
END $$;

-- The existing auth.users trigger must force Resident, despite hostile role
-- data in user-supplied metadata.
INSERT INTO auth.users(id,raw_user_meta_data) VALUES
 ('00000000-0000-0000-0000-000000000001',
  '{"full_name":"Sample Resident","role":"system_admin"}'),
 ('00000000-0000-0000-0000-000000000002',
  '{"full_name":"Sample Resident Two"}'),
 ('00000000-0000-0000-0000-000000000003',
  '{"full_name":"Sample Staff"}'),
 ('00000000-0000-0000-0000-000000000004',
  '{"full_name":"Sample Moderator"}'),
 ('00000000-0000-0000-0000-000000000005',
  '{"full_name":"Sample System Admin"}');

DO $$
BEGIN
 IF (SELECT count(*) FROM public.profiles)<>5 THEN
   RAISE EXCEPTION 'Auth trigger failed to create five profiles';
 END IF;
 IF EXISTS(SELECT 1 FROM public.profiles WHERE role<>'resident') THEN
   RAISE EXCEPTION 'Auth metadata granted a non-resident role';
 END IF;
END $$;

-- Only privileged operator/test setup changes roles. No client privilege
-- or public role-elevation endpoint is introduced.
UPDATE public.profiles SET role='maintenance_staff'
 WHERE id='00000000-0000-0000-0000-000000000003';
UPDATE public.profiles SET role='moderator'
 WHERE id='00000000-0000-0000-0000-000000000004';
UPDATE public.profiles SET role='system_admin'
 WHERE id='00000000-0000-0000-0000-000000000005';

INSERT INTO public.maintenance_reports
  (resident_id,category_id,title,description,location)
SELECT '00000000-0000-0000-0000-000000000001',
       c.id,v.title,v.description,'Room 101'
FROM (VALUES
 ('Valid sink repair','Water leak under sink'),
 ('Duplicate sink repair','Same leak already reported'),
 ('Inappropriate report','Contains content requiring moderation')
) AS v(title,description)
CROSS JOIN public.maintenance_categories c
WHERE c.name='Plumbing';

-- As a Resident: cannot mutate profile.role or call moderator RPC.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000001',false);

DO $$
DECLARE denied boolean:=false;
BEGIN
  IF (SELECT count(*) FROM public.maintenance_reports)<>3 THEN
    RAISE EXCEPTION 'Resident cannot view their own three reports';
  END IF;
  BEGIN
    UPDATE public.profiles SET role='system_admin'
    WHERE id='00000000-0000-0000-0000-000000000001';
  EXCEPTION WHEN insufficient_privilege THEN denied:=true;
  END;
  IF NOT denied THEN
    RAISE EXCEPTION 'Resident profile.role update was not denied';
  END IF;
  denied:=false;
  BEGIN
    PERFORM public.review_maintenance_report(1,'valid','');
  EXCEPTION WHEN insufficient_privilege THEN denied:=true;
  END;
  IF NOT denied THEN
    RAISE EXCEPTION 'Resident was allowed to review';
  END IF;
END $$;

-- Moderator can decide each new/unassigned report once.
SELECT set_config('request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000004',false);
DO $$
BEGIN
  IF public.review_maintenance_report(1,'valid','') IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Moderator could not approve valid report';
  END IF;
  IF public.review_maintenance_report(2,'duplicate','Already reported') IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Moderator could not reject duplicate report';
  END IF;
  IF public.review_maintenance_report(2,'valid','') IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'Second review incorrectly changed a final decision';
  END IF;
  IF (SELECT count(*) FROM public.report_reviews)<>2 THEN
    RAISE EXCEPTION 'Moderator cannot read persisted decisions';
  END IF;
END $$;

-- Moderator must not be allowed to reject without a reason.
DO $$
DECLARE denied boolean:=false;
BEGIN
  BEGIN
    PERFORM public.review_maintenance_report(3,'inappropriate','');
  EXCEPTION WHEN invalid_parameter_value THEN denied:=true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'Blank rejection reason accepted'; END IF;
END $$;

-- Admin can review inappropriate report and later may not assign it.
SELECT set_config('request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000005',false);
DO $$
BEGIN
  IF public.review_maintenance_report(3,'inappropriate','Prohibited content') IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'System admin could not review report';
  END IF;
END $$;

-- Maintenance staff sees no review metadata and cannot claim rejected.
SELECT set_config('request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000003',false);
DO $$
DECLARE denied boolean:=false;
BEGIN
  IF (SELECT count(*) FROM public.report_reviews)<>0 THEN
    RAISE EXCEPTION 'Staff can view private review decisions';
  END IF;
  IF public.claim_maintenance_report(1) IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Staff cannot claim approved report';
  END IF;
  BEGIN
    PERFORM public.claim_maintenance_report(2);
  EXCEPTION WHEN check_violation THEN denied:=true;
  END;
  IF NOT denied THEN
    RAISE EXCEPTION 'Staff was allowed to claim a duplicate report';
  END IF;
  IF public.resolve_maintenance_report(1) IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Staff cannot resolve their own approved report';
  END IF;
END $$;

-- Resident can still see resolved status; moderation decision hidden.
SELECT set_config('request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000001',false);
DO $$
BEGIN
  IF (SELECT status FROM public.maintenance_reports WHERE id=1)<>'resolved' THEN
    RAISE EXCEPTION 'Resident cannot see the resolved status';
  END IF;
  IF (SELECT count(*) FROM public.report_reviews)<>0 THEN
    RAISE EXCEPTION 'Resident can read moderator review reasons';
  END IF;
END $$;
RESET ROLE;
SELECT 'PASSED: baseline, resident-role, moderator and staff smoke checks' AS result;
