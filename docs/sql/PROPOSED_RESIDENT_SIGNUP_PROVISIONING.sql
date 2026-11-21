-- FixMate TASK #30/#35: VERIFIED EXISTING AUTH PROFILE PROVISIONING
-- READ-ONLY verification queries. Do not create another auth.users trigger.
--
-- Supabase direct read-only inspection on 2026-11-22 found:
--   auth.users trigger: on_auth_user_created
--   target: private.handle_new_user()
--   function owner: postgres; SECURITY DEFINER; search_path = ''
--   function inserts public.profiles(id,full_name,role)
--   role is the literal 'resident' (not sourced from user metadata)
--   ON CONFLICT (id) DO NOTHING
--   existing auth users: 6; existing profiles: 6; users missing profile: 0
--   authenticated cannot INSERT public.profiles or UPDATE profiles.role
-- These are snapshot observations, not a completed signup E2E test.
--
-- This file REPLACES a previously proposed redundant create-trigger SQL.
-- The new resident signup Flutter UI collects only information persisted by
-- the existing trigger: full_name. No new DDL is required for that purpose.
-- Run these SELECTs in a SQL editor with catalog access when verifying.

SELECT
  tg.tgname AS trigger_name,
  pg_get_triggerdef(tg.oid, true) AS trigger_definition
FROM pg_trigger tg
WHERE tg.tgrelid = 'auth.users'::regclass
  AND NOT tg.tgisinternal
ORDER BY tg.tgname;

SELECT
  ns.nspname AS function_schema,
  p.proname AS function_name,
  pg_get_userbyid(p.proowner) AS function_owner,
  p.prosecdef AS security_definer,
  p.proconfig AS function_settings,
  pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace ns ON ns.oid = p.pronamespace
WHERE ns.nspname = 'private'
  AND p.proname = 'handle_new_user';

SELECT
  (SELECT count(*) FROM auth.users) AS auth_users,
  (SELECT count(*) FROM public.profiles) AS profiles,
  (SELECT count(*) FROM auth.users u
     LEFT JOIN public.profiles p ON p.id = u.id
     WHERE p.id IS NULL) AS missing_profiles,
  has_table_privilege('authenticated','public.profiles','INSERT') AS direct_profile_insert_allowed,
  has_column_privilege('authenticated','public.profiles','role','UPDATE') AS direct_role_update_allowed;

-- Not yet confirmed by database catalog reads:
-- Supabase email confirmation settings, password security rules,
-- duplicate signup behavior, and successful creation with a fresh account.
--
-- Staging acceptance:
-- 1. Register a NEW test email/password through Flutter. Check Auth user and
--    matching profile exist and profile role is always resident.
-- 2. Send user metadata with role='system_admin'; verify profile is resident.
-- 3. Validate duplicate/invalid email/password and confirmation flow.
-- 4. Test the new user's own-report RLS and denied profile.role UPDATE.
-- 5. Test staff/admin accounts remain unaffected.
--
-- SAFETY: Do not test by creating users on production without approval.
-- If the existing trigger needs changes, write a separately reviewed
-- migration rather than executing the earlier redundant trigger proposal.
