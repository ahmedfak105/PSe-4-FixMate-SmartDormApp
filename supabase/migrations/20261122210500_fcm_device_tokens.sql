-- F05.2 Firebase Cloud Messaging: owner-scoped Android token registry.
-- New table only; safe for a disposable Supabase CLI database. Do not apply
-- to populated hosted FixMate until backup/review under Release Gate #47.
-- NO service-role keys or Firebase service-account secrets belong here.

create table if not exists public.push_device_tokens (
  token text primary key
    check (char_length(token) between 20 and 4096),
  user_id uuid not null references public.profiles(id) on delete cascade,
  platform text not null default 'android'
    check (platform = 'android'),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index if not exists push_device_tokens_user_id_idx
  on public.push_device_tokens (user_id);

alter table public.push_device_tokens enable row level security;

revoke all on public.push_device_tokens from public, anon, authenticated;
grant select, insert, update, delete
  on public.push_device_tokens to authenticated;

drop policy if exists "Residents view own push devices"
  on public.push_device_tokens;
create policy "Residents view own push devices"
on public.push_device_tokens for select to authenticated
using (user_id = (select auth.uid()) and exists (
  select 1 from public.profiles p
  where p.id = (select auth.uid()) and p.role = 'resident'
));

drop policy if exists "Residents register own push devices"
  on public.push_device_tokens;
create policy "Residents register own push devices"
on public.push_device_tokens for insert to authenticated
with check (user_id = (select auth.uid()) and exists (
  select 1 from public.profiles p
  where p.id = (select auth.uid()) and p.role = 'resident'
));

drop policy if exists "Residents refresh own push devices"
  on public.push_device_tokens;
create policy "Residents refresh own push devices"
on public.push_device_tokens for update to authenticated
using (user_id = (select auth.uid()) and exists (
  select 1 from public.profiles p
  where p.id = (select auth.uid()) and p.role = 'resident'
))
with check (user_id = (select auth.uid()) and exists (
  select 1 from public.profiles p
  where p.id = (select auth.uid()) and p.role = 'resident'
));

drop policy if exists "Residents unregister own push devices"
  on public.push_device_tokens;
create policy "Residents unregister own push devices"
on public.push_device_tokens for delete to authenticated
using (user_id = (select auth.uid()));

notify pgrst, 'reload schema';
