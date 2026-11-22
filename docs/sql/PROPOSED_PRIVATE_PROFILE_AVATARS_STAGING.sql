-- FixMate: proposed optional avatar extension, STAGING FIRST.
-- This is NOT installed on the populated hosted database.
-- Review together with docs/CONTROLLED_SUPABASE_ROLLOUT_TASK36_TASK39.md
-- before any production use. Changes are additive; no user rows are dropped.
--
-- The original profiles table already grants authenticated users UPDATE only
-- on full_name, building, room_number. Never grant UPDATE(role) in a client.
BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN avatar_path text;

ALTER TABLE public.profiles
  ADD CONSTRAINT fixmate_avatar_path_is_owned
  CHECK (
    avatar_path IS NULL
    OR (
      length(avatar_path) <= 250
      AND avatar_path LIKE id::text || '/%'
      AND avatar_path !~ '[[:cntrl:]]'
    )
  );

REVOKE UPDATE ON TABLE public.profiles FROM authenticated, anon;
REVOKE UPDATE (role, id, created_at) ON public.profiles FROM authenticated;
GRANT UPDATE (full_name, building, room_number, avatar_path)
  ON TABLE public.profiles TO authenticated;

-- Avoid public avatars: authenticated owner only can read/upload/delete.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profile-avatars', 'profile-avatars', false, 2097152,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
);

CREATE POLICY "FixMate avatar owner read"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'profile-avatars'
  AND (storage.foldername(name))[1] = (select auth.uid())::text
);

CREATE POLICY "FixMate avatar owner upload"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'profile-avatars'
  AND (storage.foldername(name))[1] = (select auth.uid())::text
  AND array_length(storage.foldername(name), 1) = 1
);

CREATE POLICY "FixMate avatar owner delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'profile-avatars'
  AND (storage.foldername(name))[1] = (select auth.uid())::text
);
COMMIT;

-- Required acceptance in separate authorized Staging Supabase:
-- 1. Resident, Staff, Moderator, Admin edit only OWN name/building/room.
-- 2. All four upload & read their OWN avatar via real Auth/Storage API.
-- 3. Other user's avatar download/list/delete denied by Storage RLS.
-- 4. A user cannot update role/id/created_at or another user's profile.
-- 5. Reject oversized and non-image uploads; reject cross-user avatar_path.
-- 6. Read-only users can still access previously permitted profiles.
-- 7. Existing report/photo permissions unchanged.
-- 8. Enable RLS and review migration diff / backup before live deployment.
