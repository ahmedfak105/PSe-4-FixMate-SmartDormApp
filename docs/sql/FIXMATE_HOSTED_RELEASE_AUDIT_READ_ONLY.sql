-- FixMate hosted Supabase release readiness: READ-ONLY, NO PERSONAL IDENTIFIERS
-- Verified against active project epsvagztisdovixlqehi on 2026-11-22.
-- Safe to re-run: only SELECT / information_schema / pg_catalog introspection.
-- DO NOT use this query as permission to run a migration: #47 requires
-- operator-approved reviewed additive SQL, a real backup, RESTORE proof,
-- signed-off role testing, and separate Firebase sender approval.
--
-- Intended for Supabase SQL Editor, read-only review mode.
-- Returns only aggregate counts, schema booleans, and grants.
with present as (
 select
 to_regclass('public.profiles') is not null as profiles,
 to_regclass('public.report_reviews') is not null as reviews,
 to_regclass('public.report_notifications') is not null as notifications,
 to_regclass('public.push_device_tokens') is not null as devices,
 to_regclass('public.push_delivery_outbox') is not null as push_outbox,
 to_regclass('public.user_role_audit') is not null as role_audit
)
select
 (select count(*) from public.profiles) as profiles_count,
 (select count(*) from public.maintenance_reports) as report_count,
 (select jsonb_object_agg(role,n) from (
    select role,count(*) n from public.profiles group by role
  ) q) as user_role_counts,
 (select jsonb_agg(t.relname order by t.relname)
  from pg_class t join pg_namespace ns on ns.oid=t.relnamespace
  where ns.nspname='public' and t.relkind in ('r','p')
    and not t.relrowsecurity) as unprotected_public_tables,
 has_column_privilege('authenticated','public.profiles','full_name','UPDATE') as can_edit_name_column,
 has_column_privilege('authenticated','public.profiles','building','UPDATE') as can_edit_building_column,
 has_column_privilege('authenticated','public.profiles','room_number','UPDATE') as can_edit_room_column,
 has_column_privilege('authenticated','public.profiles','role','UPDATE') as can_edit_role_column,
 exists(select 1 from information_schema.columns
    where table_schema='public' and table_name='profiles'
      and column_name='avatar_path') as avatar_column_present,
 exists(select 1 from storage.buckets
    where id='profile-avatars' and not public) as private_avatar_bucket_present,
 (select row_to_json(present) from present) as additional_features_present,
 to_regprocedure('public.review_maintenance_report(bigint,text,text)') is not null as review_rpc_present,
 to_regprocedure('public.manage_user_role(uuid,text,text)') is not null as role_management_rpc_present,
 to_regprocedure('public.manage_maintenance_category(bigint,text,boolean)') is not null as category_management_rpc_present,
 to_regprocedure('public.claim_fixmate_push_jobs(integer)') is not null as push_claim_rpc_present;

-- Deployment invariants to inspect BEFORE and AFTER approved migrations.
-- These do not grant access and do not change data or policy definitions.
select schemaname, tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname='public' and tablename in
 ('profiles','maintenance_reports','report_attachments','report_reviews',
  'report_notifications','push_device_tokens','push_delivery_outbox','user_role_audit')
order by tablename, policyname;

select p.proname, n.nspname as schema_name,
 pg_get_function_identity_arguments(p.oid) as function_signature,
 p.prosecdef as security_definer
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname in
 ('claim_maintenance_report','resolve_maintenance_report',
  'assign_maintenance_report','review_maintenance_report',
  'manage_maintenance_category','manage_user_role',
  'claim_fixmate_push_jobs')
order by p.proname;

-- No users, names, emails, phone numbers, photos, device tokens or report text
-- are returned by any query above.
