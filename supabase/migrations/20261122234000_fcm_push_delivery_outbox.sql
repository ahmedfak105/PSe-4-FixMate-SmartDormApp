-- F05.2: durable, server-only push outbox. This migration is ADDITIVE,
-- meant for a disposable local Supabase CLI stack until Release Gate #47.
-- Do not replay baseline against the populated hosted project.

create table if not exists public.push_delivery_outbox (
  id bigint generated always as identity primary key,
  notification_id bigint not null
    references public.report_notifications(id) on delete cascade,
  resident_id uuid not null references public.profiles(id),
  token text not null,
  token_fingerprint text generated always as (md5(token)) stored,
  state text not null default 'pending'
    check (state in ('pending', 'processing', 'sent', 'invalid', 'cancelled', 'failed')),
  attempts integer not null default 0 check (attempts between 0 and 5),
  next_attempt_at timestamptz not null default now(),
  claimed_at timestamptz,
  sent_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  unique (notification_id, token_fingerprint)
);

create index if not exists push_delivery_pending_idx
on public.push_delivery_outbox(state, next_attempt_at, id)
where state in ('pending', 'processing');

alter table public.push_delivery_outbox enable row level security;
revoke all on public.push_delivery_outbox
from public, anon, authenticated;
-- No browser roles can SELECT or mutate the queue or retrieve FCM tokens.
-- Only backend service_role (which bypasses RLS) handles it.

create or replace function public.queue_fixmate_report_push()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  -- Queue devices owned by this notification's Resident. A missing device
  -- is normal, so report updates never require that anyone opt into push.
  insert into public.push_delivery_outbox
    (notification_id, resident_id, token)
  select new.id, new.resident_id, d.token
  from public.push_device_tokens d
  where d.user_id = new.resident_id
  on conflict (notification_id, token_fingerprint) do nothing;
  return new;
end;
$$;

revoke all on function public.queue_fixmate_report_push()
from public, anon, authenticated;
drop trigger if exists fixmate_queue_report_push
on public.report_notifications;
create trigger fixmate_queue_report_push
after insert on public.report_notifications
for each row execute function public.queue_fixmate_report_push();

create or replace function public.cancel_fixmate_revoked_device_push()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  update public.push_delivery_outbox q
  set state = 'cancelled', last_error = null
  where q.resident_id = old.user_id and q.token = old.token
    and q.state in ('pending', 'processing');
  return old;
end;
$$;

revoke all on function public.cancel_fixmate_revoked_device_push()
from public, anon, authenticated;
drop trigger if exists fixmate_cancel_revoked_push
on public.push_device_tokens;
create trigger fixmate_cancel_revoked_push
after delete on public.push_device_tokens
for each row execute function public.cancel_fixmate_revoked_device_push();

-- Atomic claims prevent two sender invocations from sending the same job
-- concurrently. A crashed worker's lease expires after ten minutes.
create or replace function public.claim_fixmate_push_jobs(
  p_batch_size integer default 10
)
returns table (
  id bigint,
  notification_id bigint,
  resident_id uuid,
  report_id bigint,
  new_status text,
  token text,
  attempts integer
)
language plpgsql security definer set search_path = ''
as $$
begin
  -- The caller's JWT role is checked explicitly: SECURITY DEFINER's
  -- current_user is the function owner, not the invoking API role.
  if (select auth.jwt() ->> 'role') is distinct from 'service_role' then
    raise exception 'Not authorized to claim push jobs'
      using errcode = '42501';
  end if;

  return query
  with picked as (
    select q.id
    from public.push_delivery_outbox q
    where q.attempts < 5 and (
      (q.state = 'pending' and q.next_attempt_at <= now())
      or (q.state = 'processing' and
          q.claimed_at < now() - interval '10 minutes')
    )
    order by q.id
    for update skip locked
    limit least(greatest(coalesce(p_batch_size, 10), 1), 20)
  ), claimed as (
    update public.push_delivery_outbox q
    set state = 'processing',
        claimed_at = now(),
        attempts = q.attempts + 1
    where q.id in (select picked.id from picked)
    returning q.*
  )
  select c.id, c.notification_id, c.resident_id,
    n.report_id, n.new_status, c.token, c.attempts
  from claimed c
  join public.report_notifications n on n.id = c.notification_id;
end;
$$;

revoke all on function public.claim_fixmate_push_jobs(integer)
from public, anon, authenticated;
grant execute on function public.claim_fixmate_push_jobs(integer)
to service_role;

notify pgrst, 'reload schema';
