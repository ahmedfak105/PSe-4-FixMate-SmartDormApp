-- FixMate: self-service profile details and private avatars.
-- Apply only after review and verification on staging. Never grant role updates.
alter table public.profiles add column if not exists avatar_path text;

-- Current production has no UPDATE grant for authenticated users. Grant only
-- these four non-privileged columns; keep id, role, created_at protected.
revoke update on public.profiles from authenticated;
grant update (full_name, building, room_number, avatar_path)
  on public.profiles to authenticated;
grant select on public.profiles to authenticated;

-- Existing "Update own profile" RLS policy checks id = auth.uid().
-- Recreate it to make this migration usable on a clean staging database.
drop policy if exists "Update own profile" on public.profiles;
create policy "Update own profile" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-avatars', 'profile-avatars', false, 2097152,
        array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
set public = false, file_size_limit = 2097152,
    allowed_mime_types = excluded.allowed_mime_types;

-- Path: <auth.uid()>/<timestamp>.<jpg|png|webp>.
-- Never allow users to list, read or write other users' avatars.
drop policy if exists "FixMate read own avatar" on storage.objects;
create policy "FixMate read own avatar" on storage.objects
for select to authenticated
using (bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "FixMate upload own avatar" on storage.objects;
create policy "FixMate upload own avatar" on storage.objects
for insert to authenticated
with check (bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and lower(storage.extension(name)) in ('jpg','jpeg','png','webp'));

-- No UPDATE or DELETE storage policies: uploaded files are immutable.
-- Existing report-photos policies remain unchanged.
