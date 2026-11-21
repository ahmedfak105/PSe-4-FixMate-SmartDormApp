-- PROPOSED FixMate TASK #30 + #35: safe resident profile provisioning
-- Apply only to a CLONED/STAGING Supabase project after review.
-- DO NOT apply directly to the active production project without tests.
-- This creates an auth.users AFTER INSERT trigger to provision profiles.
-- Never trust client metadata for role, id, permissions or created_at.
-- Prerequisites: public.profiles exists; fixmate_private exists; DB owner can
-- create function and trigger in Supabase-managed auth schema.
--
-- Not a migration for existing Auth accounts: NO bulk backfill is attempted.
-- Staff/moderator/admin provisioning remains a separate trusted process.

BEGIN;

CREATE FUNCTION fixmate_private.create_resident_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role, building, room_number)
  VALUES (
    NEW.id,
    left(btrim(coalesce(NEW.raw_user_meta_data ->> 'full_name', '')), 100),
    'resident',
    nullif(left(btrim(coalesce(NEW.raw_user_meta_data ->> 'building', '')), 80), ''),
    nullif(left(btrim(coalesce(NEW.raw_user_meta_data ->> 'room_number', '')), 30), '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- No direct EXECUTE privileges are required by browser sessions.
REVOKE ALL ON FUNCTION fixmate_private.create_resident_profile()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER fixmate_create_resident_profile_after_signup
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION fixmate_private.create_resident_profile();

COMMIT;

-- Required STAGING acceptance tests (not yet performed):
-- A. New sign-up with valid email/password creates matching profiles.id,
--    role='resident', metadata copied into permitted profile fields.
-- B. Sign-up metadata containing role='system_admin' or 'maintenance_staff'
--    MUST still result in public.profiles.role='resident'.
-- C. Existing staff/admin accounts and role assignments remain unchanged.
-- D. Email confirmation ON and OFF; both work with the Flutter sign-up flow.
-- E. Existing duplicate registration: handled per Supabase Auth privacy behavior.
-- F. Invalid/missing metadata does not let users alter id or privilege fields.
-- G. A second manual insert/trigger conflict does not overwrite a profile.
-- H. Authentication remains operational if the app is offline or user retries.
--
-- Note: Auth triggers can block sign-up if they fail. Review function ownership
-- and existing auth.users triggers BEFORE applying to a test instance.
