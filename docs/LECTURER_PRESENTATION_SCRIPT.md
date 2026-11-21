# FixMate — Lecturer Presentation Script and Live Demo

**Evidence snapshot:** 21 Nov 2026  
**Suggested speaking time:** 7–9 minutes (plus SQL and questions)  
**Project:** FixMate – SmartDormApp, Kauno Kolegija internal internship.

> This is the spoken script for the **tested MVP**, not a claim that the full backlog or production release is complete. Use sample accounts and demo data only; never show passwords or private API keys.

## Start here: direct access to evidence

The lecturer already has repository access. Use [the one-page review index](LECTURER_REVIEW_START_HERE.md) to navigate directly to the relevant code, SQL, ERD and successful CI runs. All three submissions are currently **draft pull requests**, so they are not yet visible on `main`: [#43 Flutter](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/43), [#44 Admin](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/44), and [#42 Database & Documentation](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/42).

**Speaking approach:** keep the introduction short; for each claim show the real GitHub source or live Supabase result rather than a generic slide. Distinguish **implemented**, **tested**, and **planned** functionality.

## Before starting

Open the Flutter resident/staff app, the local admin dashboard (e.g. `http://localhost:5500`), Supabase SQL Editor, [the ERD](FIXMATE_ERD.md), and [the architecture document](DATABASE_ARCHITECTURE.md). Have authorized test resident, maintenance staff and system admin accounts ready.

## 1. Introduction (show repo or app)

"Good morning. Today I will present FixMate, our SmartDormApp project for reporting and managing maintenance problems in a student dormitory. Residents can submit requests and track progress, maintenance staff can process reports, and administrators can review reports and assign work. This is a working demonstration connected to Supabase."

## 2. System architecture (show architecture document)

"The resident and staff application is developed in Flutter. The current admin dashboard is a separate HTML, CSS and JavaScript website. Both connect to the same Supabase project. Supabase Auth handles sign-in, PostgreSQL stores relational data, private Storage holds report photos, RLS protects records, and database functions validate important report actions."

**Implementation note:** the initial backlog mentions Flutter Web administration, but the project team reported on 21 Nov 2026 that the lecturer approved the standalone HTML/CSS/JavaScript dashboard. This approval concerns the technology choice; it does not imply that unfinished admin functions are complete.

## 3. ER diagram (show the ERD)

"Our public application database has six tables, 34 columns and ten foreign keys. The main table is maintenance_reports. Each report belongs to a resident and category, and may be assigned to a staff member. Report attachments, notes and status history are linked to reports. The profiles table links to Supabase auth.users. These relationships were verified from the real database constraints."

## 4. Resident walkthrough (open Flutter resident login)

"The resident can submit a maintenance report with details, category and an optional image, and open My Reports to see its status. Reports live in PostgreSQL, while images use a private Storage bucket. We have recorded that a submitted report persists after restarting the app. In isolation tests, two resident accounts saw only their own reports."

## 5. Staff walkthrough (open Flutter maintenance staff account)

"Maintenance staff can see eligible new reports and assigned work. Claiming a report changes its state from new to in_progress and writes a history entry. The assigned worker can add notes and resolve the report; resolution writes another history entry. The protected database functions check the user's role, assignment, and report state."

## 6. Admin dashboard (show Overview, Reports, Assignments and People)

"The admin dashboard displays live report data, report statuses, assignments and existing users. It can assign an eligible new report to a maintenance employee. The report remains new until that employee claims it. People & Roles is read-only in this web MVP. A signed-in maintenance_staff test user was denied entry, while the system_admin account could access the dashboard."

## 7. Database security (show RLS documentation)

"RLS is enabled on all six application tables, and we reviewed thirteen policies. Resident report access is ownership-based, staff access follows assigned work, and role checks inside privileged RPC functions restrict status changes. We verified the authenticated database role cannot update profiles.role directly. The report-photos bucket is private, allows JPEG/PNG/WebP and limits files to five MiB. We have reviewed the Storage RLS rules, although complete live anonymous and cross-user endpoint testing remains an outstanding task."

## 8. Testing and conclusion (show PRs)

"We ran the Flutter test suite in our cloned GitHub repository: nineteen tests passed. GitHub Actions also completed successfully. We documented the SQL schema, ERD, RLS, RPC functions and Storage rules. The work is organized in draft pull requests rather than prematurely merged into main. Next we will complete remaining authorization tests, a reproducible migration and unfinished backlog features. Thank you. I am ready to answer questions."

## Read-only SQL demonstration (run in Supabase SQL Editor)

**Explain that SQL Editor may use elevated privileges, so results here are not proof of client RLS behavior.** Run individual `SELECT` statements from [FIXMATE_DEMO_QUERIES_READ_ONLY.sql](sql/FIXMATE_DEMO_QUERIES_READ_ONLY.sql):

1. Reports JOIN profiles, categories and assigned staff: demonstrates foreign keys and `LEFT JOIN` for optional assignment.
2. Count reports grouped by status: demonstrates the workflow `new / in_progress / resolved`.
3. Join status history to profiles: demonstrates recorded transitions and acting users.
4. List RLS-enabled flags from `pg_class`: demonstrates all six app tables have RLS.
5. Count profiles by role: demonstrates `resident / maintenance_staff / moderator / system_admin`.

## Anticipated lecturer questions

**Why RLS?** To constrain which database rows clients can access, not merely hide screens in the UI.

**Why SECURITY DEFINER?** The privileged routine performs a limited report update after validating role, assignment and state. Do not give every browser direct report UPDATE permission.

**Can a resident self-promote to admin?** In the inspected grants, authenticated lacks UPDATE permission on `profiles.role`. Other indirect code paths remain subject to review.

**Can two workers claim the same unassigned report?** The function uses a conditional row UPDATE; only one can transition that specific report from new to in_progress.

**Why is assignment separate from claim?** Assignment selects a staff member; claim confirms work started and changes the status.

**Is the solution finished?** It is a tested MVP, not a production release. Password recovery, notifications, full migration/testing, and role-administration enhancements are not all demonstrated as complete.

## Repository review links

- [Database Architecture](DATABASE_ARCHITECTURE.md)
- [ER diagram](FIXMATE_ERD.md)
- [Read-only SQL demo queries](sql/FIXMATE_DEMO_QUERIES_READ_ONLY.sql)
- [RLS, RPC and Storage security](DATABASE_RLS_SECURITY.md)
- [Security & QA verification](SECURITY_QA_VERIFICATION.md)
- Draft PRs: #42 documentation, #43 Flutter, #44 Admin dashboard.

**Never execute the structural `CREATE TABLE` reference SQL on the existing Supabase project.**
