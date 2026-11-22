-- F05.1 Durable owner-only in-app status notifications.
-- Isolated local first; additive-only, hosted rollout tracked under #47.

create table if not exists public.report_notifications (
  id bigint generated always as identity primary key,
  resident_id uuid not null references public.profiles(id),
  report_id bigint not null references public.maintenance_reports(id),
  new_status text not null check (
    new_status in ('new','in_progress','resolved')
  ),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index if not exists report_notifications_resident_created_idx
  on public.report_notifications (resident_id, created_at desc);

alter table public.report_notifications enable row level security;
revoke all on table public.report_notifications
  from public, anon, authenticated;
grant select on public.report_notifications to authenticated;
grant update (read_at) on public.report_notifications to authenticated;

drop policy if exists "Residents read own notifications"
  on public.report_notifications;
create policy "Residents read own notifications"
  on public.report_notifications for select to authenticated
  using (resident_id = (select auth.uid()));

drop policy if exists "Residents mark own notifications read"
  on public.report_notifications;
create policy "Residents mark own notifications read"
  on public.report_notifications for update to authenticated
  using (resident_id = (select auth.uid()))
  with check (resident_id = (select auth.uid()));

create or replace function public.record_fixmate_report_status_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    insert into public.report_notifications
      (resident_id, report_id, new_status)
    values (new.resident_id, new.id, new.status);
  end if;
  return new;
end;
$$;

revoke all on function public.record_fixmate_report_status_change()
  from public, anon, authenticated;

drop trigger if exists fixmate_report_status_notify
  on public.maintenance_reports;
create trigger fixmate_report_status_notify
after update of status on public.maintenance_reports
for each row when (old.status is distinct from new.status)
execute function public.record_fixmate_report_status_change();

notify pgrst, 'reload schema';
