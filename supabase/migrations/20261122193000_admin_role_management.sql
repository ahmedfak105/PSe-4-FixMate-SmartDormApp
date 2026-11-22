-- F06.2 Trusted System Admin role management (free local-first migration).
-- Additive-only: no changes to existing profiles schema or Auth users.
-- Never run against populated hosted FixMate outside Release Gate #47.

create table if not exists public.user_role_audit (
  id bigint generated always as identity primary key,
  actor_id uuid not null references public.profiles(id),
  target_id uuid not null references public.profiles(id),
  old_role text not null,
  new_role text not null,
  changed_at timestamptz not null default now()
);

alter table public.user_role_audit enable row level security;
revoke all on table public.user_role_audit from public, anon, authenticated;
grant select on table public.user_role_audit to authenticated;

drop policy if exists "Admins read role audit" on public.user_role_audit;
create policy "Admins read role audit"
on public.user_role_audit for select to authenticated
using (exists (
  select 1 from public.profiles
  where id = (select auth.uid()) and role = 'system_admin'
));

create or replace function public.can_manage_user_roles()
returns boolean language sql stable security definer set search_path = ''
as $
  select (select auth.uid()) is not null and exists (
    select 1 from public.profiles where id = (select auth.uid())
      and role = 'system_admin'
  );
$;

revoke all on function public.can_manage_user_roles()
  from public, anon, authenticated;
grant execute on function public.can_manage_user_roles()
  to authenticated;

create or replace function public.manage_user_role(
  p_user_id uuid, p_expected_role text, p_new_role text
)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_current_role text;
  v_result public.profiles%rowtype;
begin
  if v_actor is null or not exists (
    select 1 from public.profiles
    where id = v_actor and role = 'system_admin'
  ) then
    raise exception 'Not authorized to manage users' using errcode = '42501';
  end if;

  if p_user_id is null or p_user_id = v_actor then
    raise exception 'Administrators cannot change their own role'
      using errcode = '42501';
  end if;

  if p_new_role is null or p_new_role not in
    ('resident', 'maintenance_staff', 'moderator', 'system_admin')
    or p_expected_role is null then
    raise exception 'Invalid role' using errcode = '22023';
  end if;

  select role into v_current_role from public.profiles
    where id = p_user_id for update;
  if not found then
    raise exception 'User not found' using errcode = '22023';
  end if;
  if v_current_role is distinct from p_expected_role then
    raise exception 'Account role was changed by another administrator'
      using errcode = '40001';
  end if;

  if p_new_role = v_current_role then
    select * into v_result from public.profiles where id = p_user_id;
    return v_result;
  end if;

  update public.profiles
    set role = p_new_role
    where id = p_user_id
    returning * into v_result;

  insert into public.user_role_audit
    (actor_id, target_id, old_role, new_role)
    values (v_actor, p_user_id, v_current_role, p_new_role);

  return v_result;
end;
$$;

revoke all on function public.manage_user_role(uuid,text,text)
  from public, anon, authenticated;
grant execute on function public.manage_user_role(uuid,text,text)
  to authenticated;

notify pgrst, 'reload schema';
