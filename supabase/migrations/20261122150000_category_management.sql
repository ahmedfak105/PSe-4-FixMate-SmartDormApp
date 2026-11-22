-- F06.3 Maintenance Category Management
-- Additive, non-destructive. Apply to a disposable local Supabase first.
-- Do NOT replay the baseline on the populated hosted project.

-- A role-safe capability query lets an Admin UI show read-only categories
-- until this migration has actually been deployed to the connected database.
create or replace function public.can_manage_maintenance_categories()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1 from public.profiles
      where id = (select auth.uid()) and role = 'system_admin'
    );
$$;

revoke all on function public.can_manage_maintenance_categories()
  from public, anon, authenticated;
grant execute on function public.can_manage_maintenance_categories()
  to authenticated;

-- Normal users still see ONLY active categories via the existing
-- "View active categories" policy. An authorized admin can also read
-- inactive categories, without expanding Resident/Staff access.
drop policy if exists "FixMate admin reads all categories"
  on public.maintenance_categories;
create policy "FixMate admin reads all categories"
on public.maintenance_categories for select to authenticated
using ((select public.can_manage_maintenance_categories()));

-- Only this vetted, role-checking function may WRITE categories.
-- There are deliberately no authenticated direct INSERT/UPDATE/DELETE
-- table grants or browser-side service-role keys.
revoke insert, update, delete on public.maintenance_categories
  from authenticated;

-- Editing a category name creates a NEW category version and deactivates
-- the old one. Reports retain their historical category FK + original name.
-- Enabling/disabling an existing category leaves its ID/name unchanged.
create or replace function public.manage_maintenance_category(
  p_category_id bigint,
  p_name text,
  p_is_active boolean
)
returns public.maintenance_categories
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := btrim(p_name);
  v_original public.maintenance_categories%rowtype;
  v_result public.maintenance_categories%rowtype;
begin
  if not (select public.can_manage_maintenance_categories()) then
    raise exception 'Not authorized to manage categories'
      using errcode = '42501';
  end if;

  if v_name is null or char_length(v_name) < 2
     or char_length(v_name) > 80 or p_is_active is null then
    raise exception 'Category name must be 2–80 characters and status must be set'
      using errcode = '22023';
  end if;

  if p_category_id is null then
    insert into public.maintenance_categories(name, is_active)
    values (v_name, p_is_active) returning * into v_result;
  else
    select * into v_original
    from public.maintenance_categories
    where id = p_category_id
    for update;
    if not found then
      raise exception 'Category does not exist' using errcode = '22023';
    end if;

    if v_original.name = v_name then
      update public.maintenance_categories
      set is_active = p_is_active
      where id = p_category_id
      returning * into v_result;
    else
      -- The original category stays in the database for historical reports.
      update public.maintenance_categories
      set is_active = false
      where id = p_category_id;

      -- Existing UNIQUE(name) prevents duplicates; any error rolls back
      -- the entire rename, including the old category's deactivation.
      insert into public.maintenance_categories(name, is_active)
      values (v_name, p_is_active)
      returning * into v_result;
    end if;
  end if;

  return v_result;
end;
$$;

revoke all on function public.manage_maintenance_category(bigint,text,boolean)
  from public, anon, authenticated;
grant execute on function public.manage_maintenance_category(bigint,text,boolean)
  to authenticated;

notify pgrst, 'reload schema';
