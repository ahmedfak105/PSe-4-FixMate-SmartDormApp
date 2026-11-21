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

## 6. Scope decision requiring confirmation

The [Product Backlog](PRODUCT_BACKLOG.md) originally describes an admin interface in **Flutter Web**. The demonstrable admin dashboard is instead **standalone HTML/CSS/JavaScript**. Its current functionality can be demonstrated, but the implementation choice should be explicitly accepted by the lecturer/team if framework compliance is part of grading. The **People & Roles** screen is currently read-only; the dashboard does **not** yet provide privileged account/role edits.

## 7. Presenter materials

- [Detailed spoken presentation script](LECTURER_PRESENTATION_SCRIPT.md) — what to say and what to show.
- [Read-only SQL demo](sql/FIXMATE_DEMO_QUERIES_READ_ONLY.sql) — exact queries.
- [Security and QA summary](SECURITY_QA_VERIFICATION.md) — verified evidence and boundaries.

**Review recommendation:** assess the three Draft PRs and their acceptance criteria before merging. Do not mark unfinished backlog features as complete.
