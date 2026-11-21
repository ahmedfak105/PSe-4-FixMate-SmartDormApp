# FixMate – SmartDormApp | Lecturer Review Index

**Kauno Kolegija — Internal Internship**  
**Evidence snapshot:** 21 November 2026  
**Purpose:** A direct navigation sheet for a lecturer who already has repository access. Every link goes to the relevant source, SQL, test evidence or review PR. This describes a **working MVP**, not a finished production release.

## 1. Where to look in GitHub

| Workstream | Code / evidence | Review status |
|---|---|---|
| **Flutter resident and staff app** | [PR #43 — mobile application](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/43) · [main.dart](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/blob/feature/flutter-resident-staff/mobile/lib/main.dart) · [Report feature](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/tree/feature/flutter-resident-staff/mobile/lib/features/reports) · [Staff screens](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/tree/feature/flutter-resident-staff/mobile/lib/features/staff) | Draft PR; 19/19 Flutter tests passed locally and CI checks passed |
| **Admin web application** | [PR #44 — administrator dashboard](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/44) · [index.html](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/blob/feature/admin-web-dashboard/admin-web/index.html) · [app.js](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/blob/feature/admin-web-dashboard/admin-web/app.js) · [styles.css](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/blob/feature/admin-web-dashboard/admin-web/styles.css) | Draft PR; admin views loaded; maintenance_staff role was denied entry |
| **Database, ERD and security** | [PR #42 — documentation](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/42) · [Architecture](DATABASE_ARCHITECTURE.md) · [ERD](FIXMATE_ERD.md) · [RLS / RPC / Storage](DATABASE_RLS_SECURITY.md) | Draft PR; definitions and checks extracted from the actual Supabase project |

**Important:** None of these three PRs has been merged into `main` as of the evidence snapshot. Open the **PR branch** linked above, rather than expecting these files on `main`.

## 2. Database work to demonstrate

- **Six** application tables, **34** columns, **10** foreign keys, and roles `resident`, `maintenance_staff`, `moderator`, `system_admin`.
- [Actual-schema ERD](FIXMATE_ERD.md) shows the central `maintenance_reports` table, ownership and assigned staff, categories, photos, internal notes and status history.
- [Schema reference SQL](sql/FIXMATE_PUBLIC_SCHEMA_REFERENCE.sql) records actual column types, defaults, primary keys, foreign keys, CHECK constraints and identity generation. It is a **reference**, not a complete deployment migration; **do not run it against the live Supabase project**.
- [Read-only demo SQL](sql/FIXMATE_DEMO_QUERIES_READ_ONLY.sql) shows joins between reports, residents, categories and staff; status counts; history; internal notes; and RLS/Storage catalog flags.
- [Authorization evidence](DATABASE_RLS_SECURITY.md) documents 13 policies across six RLS-enabled app tables, seven RPC routines, the blocked direct `profiles.role` update grant, and the private `report-photos` bucket.

## 3. Recorded test evidence

- Flutter cloned-repository command: `cd mobile && flutter pub get && flutter test` → **19/19 tests passed**.
- GitHub Actions on Flutter PR branch: [successful PR workflow run](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44840755094) and [successful push workflow run](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44840755397).
- Staff role login to Admin Web → `Access denied: this account has role "maintenance_staff". Only system_admin can open this workspace.`
- Admin login → real Overview, All Reports, Assignments and People & Roles views loaded.
- Previously recorded resident/report/staff data-isolation and workflow tests: see [Security & QA Verification](SECURITY_QA_VERIFICATION.md).

**Scope caveat:** SQL Editor read-only queries may execute with elevated privileges and are **not** a replacement for a normal client's RLS test. Code and policy reviews are not a penetration test.

## 4. Suggested demonstration order (7–9 minutes)

1. **45 s — Introduction.** Show the repository and explain the problem: maintenance reporting and response in a dormitory.
2. **55 s — Architecture.** Show [Database Architecture](DATABASE_ARCHITECTURE.md): Flutter client + standalone Admin Web + Supabase Auth/PostgreSQL/Storage.
3. **60 s — ERD.** Show [ER diagram](FIXMATE_ERD.md), starting with `maintenance_reports`.
4. **70 s — Resident.** Create/show a report, optional attachment, My Reports and report details.
5. **70 s — Maintenance Staff.** Claim an eligible report, add internal notes, resolve it and show status history.
6. **55 s — Admin.** Show Overview, All Reports, Assignments and the read-only People & Roles page.
7. **65 s — SQL.** Run a multi-table JOIN and then a read-only status/history query; explain PK/FK and `LEFT JOIN`.
8. **50 s — Security & QA.** RLS, RPC role checks, private photo Storage, successful CI, and remaining work.

Use **test accounts and test reports only**; do not show real passwords, session tokens or private API keys.

## 5. Technical questions likely to arise

- **Why RLS as well as UI role checks?** Client-side screens are not a security boundary; database policies restrict row access.
- **Why do status changes use RPC functions?** Their bodies verify caller role, report state and assigned worker before privileged changes.
- **Does Admin assignment start the repair?** No. Assignment sets a staff ID and leaves status `new`. Claiming changes `new → in_progress`.
- **Could two staff members claim the same unassigned report?** The conditional SQL UPDATE prevents two successful state transitions on that same report.
- **Can a resident edit `profiles.role`?** The checked `authenticated` grants deny direct UPDATE on that column; indirect privileged paths still need review.
- **What remains?** A full reproducible migration, additional direct-API permission tests and remaining backlog scope such as notifications, password recovery, and user/role administration.

## 6. Admin technology choice — lecturer approval reported

The [Product Backlog](PRODUCT_BACKLOG.md) originally describes an admin interface in **Flutter Web**. The project team reported on **21 November 2026** that the lecturer **approved** the **standalone HTML/CSS/JavaScript** admin dashboard. This removes the technology-choice blocker; it does **not** mean every admin acceptance criterion has been met. The **People & Roles** screen is currently read-only; the dashboard does **not** yet provide privileged account/role edits. This note records a team-reported verbal confirmation, not independently attached written approval.

## 7. Project Board progress

The [Feature & Epic Status Reconciliation](FEATURE_EPIC_STATUS_PLAN.md) classifies all **22 Features**, **6 Epics** and **12 implementation Tasks** against acceptance criteria. Status updates for the lecturer's GitHub Project must be matched by **item title / Feature ID**, not by issue number; the lecturer and student repositories use different task numbering. The target after verification is **9 Done**, **23 In Progress**, **8 Todo** (40 total). This is a **proposed target**, not proof of live synchronization.

## 8. Presenter materials

- [Detailed spoken presentation script](LECTURER_PRESENTATION_SCRIPT.md) — what to say and what to show.
- [Read-only SQL demo](sql/FIXMATE_DEMO_QUERIES_READ_ONLY.sql) — exact queries.
- [Security and QA summary](SECURITY_QA_VERIFICATION.md) — verified evidence and boundaries.

**Review recommendation:** assess the three Draft PRs and their acceptance criteria before merging. Do not mark unfinished backlog features as complete.

## Moderator feature progress (not yet part of the tested baseline)

TASK #39 has a proposed implementation in PRs #42/#44: the new [Moderator Review page](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/blob/feature/admin-web-dashboard/admin-web/moderator.html), a [proposed database migration](sql/PROPOSED_MODERATOR_REVIEW_MIGRATION.sql), and the [staging test plan](MODERATOR_REVIEW_STAGING_TEST_PLAN.md). **The migration has not been applied to Supabase**; the feature must not be demonstrated as working end-to-end until staging and permission tests succeed. The six-table/13-policy counts elsewhere in this index remain the baseline observed before this proposed schema change.

## Resident registration progress (not yet part of the tested baseline)

A feature-flagged Flutter resident sign-up form is now in [PR #43](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/43) and the matching [proposed Auth-to-profile trigger](sql/PROPOSED_RESIDENT_SIGNUP_PROVISIONING.sql) is documented in PR #42. The default remains **disabled** until the backend trigger is reviewed and deployed/tested on staging, so the lecturer should not be told that registration is end-to-end complete yet.

## Live Supabase inspection — 22 November 2026

Connected to the existing FixMate Supabase project in **read-only mode**. All six `public` application tables have RLS enabled. Six Auth accounts have matching profiles (no missing profile). The existing `on_auth_user_created` trigger calls `private.handle_new_user()` and forces new profiles to role `resident`; do **not** install a second signup trigger. The previously proposed signup SQL file was revised to contain **read-only verification queries**. Flutter registration is still feature-flagged off until fresh-account end-to-end tests pass.

The moderator review schema/RPC remains **proposed only**; no `report_reviews` table exists in live Supabase and there are no moderator profiles in the current database snapshot. The Supabase project has **no tracked migration history and no development branch** in the connector results. Do not run the moderator migration on live production solely to make the demo work.

## Task #34 — backend rebuild documentation (draft)

[Reproduction guide](DATABASE_REPRODUCTION_GUIDE.md) links to the [catalog-derived SQL baseline draft](sql/VERIFIED_BASELINE_RECONSTRUCTION_DRAFT.sql), [8-category seed](sql/VERIFIED_CATEGORY_SEED_DRAFT.sql), and [read-only verification queries](sql/BASELINE_READ_ONLY_VERIFICATION.sql). This is substantial documentation progress on Task #34, but has **not been replayed on a clean Supabase environment**, so deployment reproducibility remains unverified. **No changes were made to the active project's database.**

## Role-based account provisioning evidence

[Trusted Staff / Moderator / Admin Provisioning](TRUSTED_ROLE_PROVISIONING.md) documents safe operator-only role changes and the negative API tests required by TASK #35. Ordinary resident signup cannot grant privileged roles. This is documentation of an existing security model, **not evidence that the Moderator end-to-end workflow has passed**.
