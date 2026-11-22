# Hosted Supabase Read-Only Audit — 22 November 2026

**Project:** PSe-4 FixMate Project (`epsvagztisdovixlqehi`)  
**Audit scope:** connected hosted project, read-only API introspection and a single SELECT query  
**Release:** NO-GO for hosted changes pending [#47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47)

## Current inventory — verified live, not inferred from local tests

| Item | Current hosted result |
| --- | --- |
| Project health | ACTIVE_HEALTHY |
| Public application tables | Six: `profiles`, `maintenance_categories`, `maintenance_reports`, `report_attachments`, `report_notes`, `report_status_history` |
| RLS on those tables | Enabled on all six |
| Current reported row counts | Profiles 6; Categories 8; Reports 5; Attachments 1; Notes 2; History 8 |
| Hosted migration history | Empty (0 entries) |
| Hosted Supabase development branches | None (0 branches) |
| `report_reviews` | Absent (0) |
| Public `review_maintenance_report` RPC | Absent (0) |
| `fixmate_block_rejected_report_work` trigger | Absent (0) |
| Reports violating proposed field validation | 0 |
| Reports referencing missing/inactive category | 0 |

All counts are point-in-time observations; results may change as the application is used. The SQL queried only counts and catalog metadata, not report descriptions or private account records.

## Security advisor (live snapshot)

- WARN: Leaked password protection disabled — owner must review [Supabase password protection guidance](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). No Auth setting changed here.
- No additional security advisor findings reported in this snapshot. An advisor result is not an exhaustive security penetration test.

## Performance advisor (live snapshot)

- INFO: Nine unindexed foreign keys across the reporting tables. Proposed fresh-database index migration exists but **has not been applied** to hosted Supabase. [Supabase index advisor](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys).
- WARN: Three tables with multiple permissive authenticated SELECT policies: `maintenance_reports`, `profiles`, `report_attachments`. Multiple permissive RLS policies may cost query time; this finding does **not** by itself demonstrate an authorization bypass. [Policy advisor](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies).
- Do not merge policies or alter indexes without reviewing query plans and preserving all positive/negative role tests.

## Evidence-producing SQL (read only)

```sql
select
 (select count(*) from information_schema.tables
  where table_schema='public' and table_name='report_reviews') as review_tables,
 (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='review_maintenance_report') as review_rpcs,
 (select count(*) from pg_trigger
  where tgrelid='public.maintenance_reports'::regclass
  and tgname='fixmate_block_rejected_report_work' and not tgisinternal) as rejection_guards,
 (select count(*) from public.maintenance_reports
  where btrim(title)='' or btrim(description)=''
  or location is null or btrim(location)='' or char_length(title)>120) as invalid_report_fields,
 (select count(*) from public.maintenance_reports r where not exists
  (select 1 from public.maintenance_categories c
   where c.id=r.category_id and c.is_active)) as inactive_category_refs;
```

**Observed result:** `0, 0, 0, 0, 0` in displayed column order.

## Release interpretation

1. The already populated hosted schema is *not* identical to a freshly initialized local database. **Do not execute `supabase db push` of the five fresh-baseline migrations against this project.**
2. The four-role application, validation, and Moderator review flows have passed local tests; this does **not** mean the new Moderator DB table or RPC is available remotely.
3. Await authorized isolated staging, reviewed backup/restore and migration-history reconciliation, exact additive SQL review, and negative access tests as documented in [release decision checklist](STAGING_ACCEPTANCE_RELEASE_DECISION.md).
4. No schema DDL, writes to user tables, privileged key retrieval, Auth setting changes, branch creation, production deployment or merge were performed for this audit.
