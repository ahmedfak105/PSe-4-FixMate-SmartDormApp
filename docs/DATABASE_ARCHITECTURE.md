# FixMate – SmartDormApp: Database Architecture & Structure

**Institutional project:** FixMate dormitory maintenance reporting system  
**Backend:** Supabase / PostgreSQL (Auth, relational database, Storage, RLS, RPC)  
**Evidence snapshot:** 21 November 2026  
**Source:** SQL Editor outputs of table columns, constraints, ID identity settings, RLS policies, PostgreSQL role grants, RPC definitions and Storage settings supplied by the project team.

> This document describes the **observed** database state. It is not a full database dump or a certification of production security. In particular, the reconstruction SQL is a **structural reference for a new database**, not a migration to apply to the live project.

## 1. System layout

The **Flutter application** implements resident and maintenance-staff experiences. A separate **HTML/CSS/JavaScript admin web dashboard** provides administrator views. Both connect to the same Supabase backend using its public client configuration and user authentication. The database enforces relevant authorization through grants, RLS policies and checks inside privileged functions.

```text
                    FixMate Frontend Applications
       Flutter Resident & Staff       Admin Web Dashboard
                       \                   /
                        \                 /
                         Supabase Authentication
                             auth.users
                                 |
                           public.profiles
                      (identity and app role)
                                 |
             PostgreSQL public relational tables
         reports / categories / photos / notes / history
                  |                         |
             RLS policies            public RPC wrappers
                                             |
                                  fixmate_private functions
                                             |
                                 validated report operations

                 Supabase Storage (private report-photos)
                     storage.objects + Storage RLS
```

## 2. Verified schema inventory

**Six application tables; 34 columns; 6 primary keys; 10 foreign keys; 1 unique constraint; 3 CHECK constraints.**

| Table | Columns | Primary key | Purpose |
|---|---:|---|---|
| `profiles` | 6 | `id uuid` | Application identity, role, building and room |
| `maintenance_categories` | 3 | `id bigint` | Selectable active maintenance categories |
| `maintenance_reports` | 9 | `id bigint` | Resident reports, category, assignee, status, location |
| `report_attachments` | 5 | `id uuid` | Photo metadata and Storage object path |
| `report_notes` | 5 | `id bigint` | Internal staff/admin maintenance notes |
| `report_status_history` | 6 | `id bigint` | Audit record of report status transitions |

`auth.users` is managed by Supabase and **is not counted** as one of these six application tables. `profiles.id` references `auth.users(id)` with `ON DELETE CASCADE`.

### Identity generation and defaults

- `maintenance_categories.id`, `maintenance_reports.id`, `report_notes.id`, `report_status_history.id` use **`bigint GENERATED ALWAYS AS IDENTITY`**.
- `profiles.id` is `uuid` and has no SQL default in the supplied schema.
- `report_attachments.id` is `uuid DEFAULT gen_random_uuid()`.
- Timestamp columns use `timestamptz DEFAULT now()` and `NOT NULL`.
- `profiles.full_name DEFAULT ''`, `profiles.role DEFAULT 'resident'`, `maintenance_reports.status DEFAULT 'new'`, `maintenance_categories.is_active DEFAULT true`.

### Relationships

- `maintenance_reports.resident_id → profiles.id` (required)
- `maintenance_reports.assigned_to → profiles.id` (optional)
- `maintenance_reports.category_id → maintenance_categories.id` (required)
- `report_attachments.report_id → maintenance_reports.id` (`ON DELETE CASCADE`)
- `report_attachments.uploaded_by → profiles.id`
- `report_notes.report_id → maintenance_reports.id` (`ON DELETE CASCADE`)
- `report_notes.author_id → profiles.id`
- `report_status_history.report_id → maintenance_reports.id` (`ON DELETE CASCADE`)
- `report_status_history.changed_by → profiles.id` (nullable)
- `profiles.id → auth.users.id` (`ON DELETE CASCADE`)

Only the four listed child/report and profile/auth foreign keys have observed `ON DELETE CASCADE`. Other foreign keys have no explicit delete action in the supplied definitions (PostgreSQL's default `NO ACTION` behavior).

### Database validations

`profiles.role` is restricted to:

```text
resident | maintenance_staff | moderator | system_admin
```

`maintenance_reports.status` and `report_status_history.new_status` are restricted to:

```text
new | in_progress | resolved
```

`maintenance_categories.name` is unique. `report_status_history.old_status` is nullable and no CHECK on it was listed.

## 3. Authorization layers

### Authentication and database privileges

Supabase Auth identifies the current account through `auth.uid()`; `profiles.role` gives its application role. The `authenticated` PostgreSQL role has **no table-level UPDATE grant on `profiles`** and **no UPDATE grant on `profiles.role`**, but does have column-specific UPDATE permission on `profiles.full_name`. The `profiles` own-row RLS UPDATE policy further restricts edits to the caller's row. No user-defined `profiles` triggers were found.

### Row Level Security

RLS is enabled on **all six public tables**, with **13 policies** in the team's export. Key rules:

- Residents may submit a new report for themselves with no assignee and view only their own reports.
- Maintenance staff can view new unassigned reports and reports assigned to them.
- Moderator and system admin roles can view reports through the staff/admin policy.
- Notes are visible/writable by assigned staff and moderator/admin roles; nonempty content is required for insertion.
- Attachment metadata and history reads depend on visibility of the referenced report, with additional resident-specific photo metadata policies.
- Admins can view all profiles through `fixmate_private.current_user_is_system_admin()`; all authenticated users can see their own profile.

See [DATABASE_RLS_SECURITY.md](DATABASE_RLS_SECURITY.md) for exact policy names, grant evidence and important caveats.

### Privileged RPC functions

Seven function definitions were reviewed. Three `public` SQL wrappers call four `fixmate_private` routines:

| Client RPC | Internal authorization | Main transition |
|---|---|---|
| `public.claim_maintenance_report(report_id)` | Current user must be `maintenance_staff`; report new and unassigned or already assigned to caller | `new → in_progress`; insert history |
| `public.assign_maintenance_report(report_id, staff_id)` | Current user moderator/admin; target role is maintenance staff; report new and unassigned | Sets staff assignment, status stays `new` |
| `public.resolve_maintenance_report(report_id)` | Current user maintenance staff; report assigned to caller and in progress | `in_progress → resolved`; insert history |

`fixmate_private.current_user_is_system_admin()` is the fourth internal routine. All four internal routines are `SECURITY DEFINER`; three public wrappers are `SECURITY INVOKER`. All seven have empty `search_path` settings and allow EXECUTE to `authenticated`, not `anon`, according to inspected privileges. The internal schema has USAGE for `authenticated`; internal function role checks are therefore crucial.

The claim update is conditional and atomic for one report. A single staff member can nevertheless claim more than one distinct report; the function has no concurrent workload limit.

## 4. Storage architecture

Supabase bucket `report-photos` is **private** (`public = false`), maximum **5 MiB** per object, with allowed types `image/jpeg`, `image/png` and `image/webp`.

Three `storage.objects` policies were supplied:

1. `fixmate_resident_read_photos` (SELECT for authenticated; folder UUID and linked report owner must match caller)
2. `fixmate_resident_upload_photos` (INSERT for authenticated; similar ownership rule)
3. `fixmate_staff_admin_read_photos` (SELECT for authenticated; staff must be assigned, while moderator/admin may read; requires two folder segments)

`storage.objects` has RLS enabled, `relforcerowsecurity = false`. Table-level grants allow SELECT and INSERT to `authenticated` and SELECT to `anon`. **The `anon` SELECT grant does not itself allow reading stored photo rows**: all enumerated RLS policies target `authenticated`, so ordinary `anon` requests should find no authorized rows, subject to runtime validation. The bucket's private setting independently prevents ordinary public URL access.

**Open review:** resident upload/read policies lack the exact two-folder count check present in the staff/admin SELECT policy. Direct cross-account and anonymous Storage tests remain outstanding.

## 5. Verified testing and outstanding work

- The project team reported **19/19 Flutter tests passing** in the locally cloned repository.
- The GitHub Flutter CI PR and push runs completed successfully on the corresponding Flutter branch.
- The dashboard has been observed admitting an admin account and denying a logged-in `maintenance_staff` account.
- SQL catalog checks confirm table relationships, user role column grants, RPC security modes/bodies and Storage bucket/policy metadata.
- **Still needed:** end-to-end API negative testing, function owner/privilege review, complete index and trigger inventory, full migration history, and reproducible deployment migration.
- **Repository workflow:** Flutter, Admin Web and documentation are separate draft pull requests, not yet merged into `main`.

## 6. Supporting project files

- [Editable ERD](erd/FIXMATE_ERD.mmd)
- [PostgreSQL structural reference (NOT for existing live DB)](sql/FIXMATE_PUBLIC_SCHEMA_REFERENCE.sql)
- [Read-only SQL demonstration queries](sql/FIXMATE_DEMO_QUERIES_READ_ONLY.sql)
- [RLS, RPC and Storage Security Evidence](DATABASE_RLS_SECURITY.md)
- [Security & QA Verification Summary](SECURITY_QA_VERIFICATION.md)

## 7. Suggested lecturer demonstration order

1. Introduce architecture: Flutter application + admin web + Supabase Auth/PostgreSQL/Storage.
2. Show the ERD and explain `maintenance_reports` as the central table.
3. Show `profiles` identity/roles and the `CHECK` and `FOREIGN KEY` constraints.
4. Run **read-only** JOIN queries for reports, category, resident, assigned staff, status history, and photo metadata.
5. Demonstrate resident-owned report and maintenance-staff processing, then admin-only dashboard access.
6. Explain RLS, the `public` RPC façade over protected internal functions, and the private photo bucket.
7. End with tested results, constraints and explicit remaining work.

**Version note:** This document is an evidence-based structural snapshot of the demonstrated backend, not a claim that every backlog feature or deployment migration is finished.
