-- TASK #36: synthetic negative tests for proposed report-input validation.
-- Run AFTER baseline + category seed + moderator migration + earlier role smoke
-- on the same disposable PostgreSQL test database. Never run against production.

-- Create an archived category as the trusted test operator.
INSERT INTO public.maintenance_categories(name,is_active)
VALUES ('Archived smoke category',false);

-- Make the test category ID available without granting residents access to
-- inactive category rows, which remain hidden by the category SELECT policy.
SELECT set_config('fixmate.test_archived_category_id',
  (SELECT id::text FROM public.maintenance_categories
   WHERE name='Archived smoke category'),false);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000001',false);

DO $$
DECLARE
  plumbing bigint;
  archived bigint;
  denied boolean;
  n bigint;
BEGIN
  SELECT id INTO plumbing FROM public.maintenance_categories
  WHERE name='Plumbing';
  archived := current_setting('fixmate.test_archived_category_id')::bigint;

  -- Valid, own report with active category still works.
  INSERT INTO public.maintenance_reports
    (resident_id,category_id,title,description,location)
  VALUES ('00000000-0000-0000-0000-000000000001',
          plumbing,'Door does not shut',
          'The dormitory entry door will not close.','Room 101')
  RETURNING id INTO n;
  IF n IS NULL THEN RAISE EXCEPTION 'Valid resident report not inserted'; END IF;

  denied:=false;
  BEGIN
    INSERT INTO public.maintenance_reports
      (resident_id,category_id,title,description,location)
    VALUES ('00000000-0000-0000-0000-000000000001',
            plumbing,'   ','Real description','Room 101');
  EXCEPTION WHEN check_violation THEN denied:=true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'Whitespace-only title accepted'; END IF;

  denied:=false;
  BEGIN
    INSERT INTO public.maintenance_reports
      (resident_id,category_id,title,description,location)
    VALUES ('00000000-0000-0000-0000-000000000001',
            plumbing,'Broken furniture','   ','Room 101');
  EXCEPTION WHEN check_violation THEN denied:=true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'Whitespace-only description accepted'; END IF;

  denied:=false;
  BEGIN
    INSERT INTO public.maintenance_reports
      (resident_id,category_id,title,description,location)
    VALUES ('00000000-0000-0000-0000-000000000001',
            plumbing,'Broken furniture','The shelf has fallen',' ');
  EXCEPTION WHEN check_violation THEN denied:=true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'Whitespace-only location accepted'; END IF;

  denied:=false;
  BEGIN
    INSERT INTO public.maintenance_reports
      (resident_id,category_id,title,description,location)
    VALUES ('00000000-0000-0000-0000-000000000001',
            plumbing,repeat('X',121),'Too long title','Room 101');
  EXCEPTION WHEN check_violation THEN denied:=true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'Title over 120 chars accepted'; END IF;

  denied:=false;
  BEGIN
    INSERT INTO public.maintenance_reports
      (resident_id,category_id,title,description,location)
    VALUES ('00000000-0000-0000-0000-000000000001',
            archived,'Archived category misuse','Must be rejected','Room 101');
  EXCEPTION WHEN insufficient_privilege THEN denied:=true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'Inactive category accepted'; END IF;

  -- A foreign resident_id must also be rejected by the existing RLS rule.
  denied:=false;
  BEGIN
    INSERT INTO public.maintenance_reports
      (resident_id,category_id,title,description,location)
    VALUES ('00000000-0000-0000-0000-000000000002',
            plumbing,'Foreign-owned report','Must be rejected','Room 101');
  EXCEPTION WHEN insufficient_privilege THEN denied:=true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'Forged resident ID accepted'; END IF;
END $$;

RESET ROLE;
SELECT 'PASSED: backend report input and active-category checks' AS result;
