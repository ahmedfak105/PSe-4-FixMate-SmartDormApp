# FixMate — Live Supabase Read-Only Audit (22 November 2026)

**Project:** `PSe-4 FixMate Project` (`epsvagztisdovixlqehi`)  
**Method:** Supabase connector read-only catalog checks (`list_tables`, `list_migrations`, `list_branches`, `execute_sql`, Security/Performance/Health Advisors).  
**Safety:** No DDL, report writes, Auth user creation, or Storage changes were performed.

## Verified baseline

| Check | Result |
|---|---|
| Postgres | 17.11 |
| Supabase project status | ACTIVE_HEALTHY |
| Application tables in `public` | 6 |
| RLS-enabled `public` application tables | 6/6 |
| `public` RLS policies | 13 |
| `auth.users` count | 6 |
| `public.profiles` count | 6 |
| Auth users missing a profile | 0 |
| Profile roles (count only) | resident 3, maintenance_staff 2, system_admin 1, moderator 0 |
| Maintenance reports | 5 |
| `public.report_reviews` | Not present |
| `public.review_maintenance_report(bigint,text,text)` | Not present |
| Non-internal triggers on `public.maintenance_reports` | 0 |
| Tracked migrations | 0 |
| Supabase development branches | 0 |

## TASK #30 / #35 — Auth and role provisioning

`auth.users` already has `on_auth_user_created` calling `private.handle_new_user()`. The existing function is owned by `postgres`, is `SECURITY DEFINER`, has empty search path, and inserts the new user ID, full name and literal role `resident` into `public.profiles`. The function ignores user metadata for authorization. `authenticated` has no direct `INSERT` grant on `public.profiles` and no direct `UPDATE` grant on its `role` column.

**Corrective action:** Do not install a second Auth trigger. The previous proposed signup SQL was replaced with read-only verification queries under the same filename, and the Flutter form removed optional building/room fields not currently persisted by the trigger. The `ENABLE_RESIDENT_SIGNUP` feature flag remains off pending actual sign-up, email confirmation and role-denial tests in staging. Existing users having profiles **does not** prove new sign-up succeeds.

## TASK #39 — Moderator backend

The moderator page exists on GitHub, but the project has **no review table/RPC**, and there is currently **no moderator profile** to validate the view. The proposed [moderator SQL](sql/PROPOSED_MODERATOR_REVIEW_MIGRATION.sql) must be reviewed and tested in staging, including rejection/assignment races, photo access, RLS, and invalid role requests. Do not run it directly on the live project based only on this audit.

## TASK #34 — Schema/index/migration gaps

Supabase Performance Advisor reported **9 unindexed foreign keys** in existing application tables: `maintenance_reports` (resident_id, category_id, assigned_to), `report_attachments` (report_id, uploaded_by), `report_notes` (report_id, author_id), `report_status_history` (report_id, changed_by). Catalog inspection found only primary/unique indexes in these tables.

A separate [proposed supporting-index SQL](sql/PROPOSED_FOREIGN_KEY_INDEXES.sql) lists nine non-unique BTREE indexes for review on staging. **No index was applied** to the active database.

The project exposes **zero tracked migrations** and **zero development branches** via the connected project. A reproducible, ordered baseline must be built before claiming new branches faithfully reproduce the live backend. A Supabase development branch created using empty migration history may not contain the existing manually created schema.

## Advisor findings

- **Security warning:** Leaked Password Protection Disabled. [Supabase password security documentation](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
- **Performance info:** 9 unindexed foreign keys. [Advisor guide](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys).
- **Performance warning:** 3 sets of multiple permissive SELECT RLS policies (maintenance_reports, profiles, report_attachments). This is a performance observation, not evidence those policies are insecure. [Advisor guide](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies).
- **Health:** No health advisories returned.

## Evidence / remaining sign-off

1. Verify new-account signup and default Resident role with **test credentials**, not SQL Editor role impersonation.
2. Create or select a safe staging environment; inspect price and obtain authorization for any new paid branch/project before creation.
3. Capture a complete baseline of table schema, indexes, constraints, grants, RLS, Storage policies, roles, functions, and triggers as ordered migrations.
4. Apply proposed moderation/index changes on staging and repeat security/performance advisors.
5. Run negative tests with actual Resident, Staff, Moderator, Admin sessions and verify existing claim/resolution workflows.
6. Only then update GitHub issue/board statuses and merge reviewed PRs.

**The audit is a verification snapshot, not a production release approval or proof of all Acceptance Criteria.**
