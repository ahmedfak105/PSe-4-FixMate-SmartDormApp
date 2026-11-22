> **HISTORICAL DRAFT — superseded on 22 Nov 2026.** Several statements below (six-table hosted backend, absent Moderator/Admin APIs, unmerged implementation branches) no longer describe the live project. For accurate presentation and test evidence use the [current lecturer handoff](LECTURER_FINAL_HANDOFF_CURRENT_2026-11-22.md) and [current 11-table ERD](FIXMATE_HOSTED_ERD.md). The hosted FCM Edge sender is ACTIVE v1, but full Android background delivery is still pending. Do **not** use this older draft verbatim with your lecturer.\n\n> **Current implementation acceptance — 22 Nov 2026:** The original **12/12 TASK issues are closed** following reproducible local Flutter/Supabase/API/Storage/Chrome tests. Five CLI-named migrations build a fresh local environment including report validation and Moderator review. **This is NOT hosted deployment or lecturer final sign-off.** The populated remote still has the original six application tables and empty migration history; [RELEASE GATE #47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47) tracks approved backup/staging/reconciliation/target-project deployment. [Integrated Draft PR #46](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/46) remains unmerged.

# FixMate — Lecturer Presentation and Live Demonstration

**Prepared for:** Kauno Kolegija Internal Internship  
**Current evidence:** Integrated release from 22 November 2026  
**Speaking time:** about 7–9 minutes, plus questions and optional SQL examples  
**Code under review:** [Integrated Draft PR #46](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/46)

> Present the implemented and locally tested MVP accurately. The GitHub integration branch includes the Flutter Mobile and **Flutter Web** applications, backend migration files and documentation. The original hosted Supabase project is **not** updated with the proposed Moderator/report-validation SQL. Do not describe it as a production release or a merged `main` branch.

## Before presenting

1. Open [Integrated PR #46](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/46), [project README](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/tree/integration/lecturer-review-2026-11-22) and the [original six-table ERD](FIXMATE_ERD.md). Keep the [proposed Moderator ERD](erd/FIXMATE_PROPOSED_MODERATOR_ERD.mmd) separate.
2. Prepare a **separate local Supabase or approved staging** environment with dummy users for the four roles: `resident`, `maintenance_staff`, `moderator`, and `system_admin`. The proposed seventh-table Moderator SQL is available **only in the tested local/staging build**, not on the unchanged hosted project.
3. Open a Resident/Staff Flutter app (Android emulator/device or Flutter run) and the Flutter Web Operations application. For the latter, run `flutter run -d chrome --dart-define=FIXMATE_OPERATIONS_WEB=true` inside `mobile/`, or serve the compiled Web artifact on a web server.
4. Use **only the public Supabase URL and publishable/anon key**. Never show passwords, service-role keys, private Storage object URLs or real resident personal data.
5. Have one valid and one duplicate dummy report ready, with a synthetic photo for review. Ensure a Moderator account exists in the **test** environment. Do not use live user accounts for a demonstration.

## 0:00–0:45 | Introduction

"Good morning. Today we are presenting FixMate – SmartDormApp, our dormitory maintenance reporting project. It allows residents to submit maintenance requests, track progress, and attach photos. Maintenance staff can claim and resolve work, while moderators review submissions and administrators monitor reports and assign employees.

Our aim was to build a realistic system with a Flutter client, a Flutter Web operations workspace, a Supabase backend, a documented database, and automated tests."

**Show:** project README and integrated PR #46.

## 0:45–1:45 | Architecture and database

"Our application has two Flutter experiences: a Resident and Staff app, and a role-specific Flutter Web operations interface for Maintenance Staff, Moderators and System Administrators. Both use the same backend contract.

Supabase Authentication handles user sessions. PostgreSQL stores reports, categories, profiles, notes, attachments metadata and status history. Supabase Storage stores uploaded photos in a private bucket. Row Level Security, database grants and protected functions enforce permissions; simply hiding a button is not our security model.

The current hosted system has six public application tables. We have a separate proposed seventh table, report_reviews, which records Moderator decisions. We document these as two distinct schema states."

**Show:** [Database Architecture](DATABASE_ARCHITECTURE.md), [baseline ERD](FIXMATE_ERD.md) and [proposed Moderator ERD](erd/FIXMATE_PROPOSED_MODERATOR_ERD.mmd).

## 1:45–2:40 | Resident workflow

"I will start with a resident account. New users register with email, password and name, and the existing Auth trigger provisions the role Resident. There is no option to choose an Admin or Staff role during registration.

A resident submits a report with its title, description, location, category and optionally a photo. The report is associated with the authenticated owner. In My Reports, the resident sees only their own submitted reports and can follow their status."

**Demonstrate:** Resident sign-in, create a dummy maintenance report, My Reports, report details. If time is short, use a pre-created test report.

## 2:40–3:35 | Admin operations in Flutter Web

"I will now open the actual Flutter Web operations interface. Users with the Resident role are denied access. The System Admin sees a dashboard with report counts, statuses, searchable reports, a People directory and maintenance assignments.

The administrator can assign an eligible New report to a Maintenance Staff member. This does not start the work automatically; the report remains New until the employee claims it. Role changes are deliberately read-only in this UI and require a trusted provisioning process."

**Demonstrate:** Resident access denied, Admin dashboard, report search, optionally assign an unclaimed valid test report.

## 3:35–4:35 | Staff claim and resolution

"The staff member signs in to view Available Reports and My Jobs. Claiming an eligible report calls a protected PostgreSQL function, which checks the role and report state. A successful claim moves the report from New to In Progress and records a status-history entry. Only the assigned staff member may resolve their report, which changes its status to Resolved.

We also tested two simultaneous claim attempts and verified that only one wins for the same report."

**Demonstrate:** Staff claim → My Jobs → Resolve → resident sees the updated status and staff sees the status timestamp, where RLS permits.

## 4:35–5:35 | Moderator review

"Moderators review New, unassigned reports. They can read report details and permitted private photos, then select Valid, Duplicate or Inappropriate. Rejected reports require a reason. The decision is persisted in the review table, and the proposed backend guard prevents rejected reports from being claimed or assigned.

This feature was tested against a disposable local Supabase environment with the proposed migration applied. The original hosted project does not have the new review table and RPC yet, so we are not claiming that Moderator review is available there."

**Demonstrate only on local/staging:** Moderator sign-in, preview photo, make a Duplicate decision with a reason and confirm it is saved.

## 5:35–6:35 | SQL, RLS and security

"The original database has six RLS-protected public tables. We also inspected the three Storage policies for private report photos. A Resident cannot update their role directly, read another resident's reports or view another resident's private images. The status changes and review operations use role-checked database RPC functions, not arbitrary client updates.

We have five ordered Supabase CLI migrations for rebuilding a **fresh local database**: the six-table baseline, eight maintenance categories, nine supporting foreign-key indexes, stricter report validation and the proposed Moderator review table/RPC. Their clean local reset succeeded, but those baseline migrations must not be pushed over an already populated database with no recorded migration history."

**Show two or three read-only SELECT statements** from [FIXMATE_DEMO_QUERIES_READ_ONLY.sql](sql/FIXMATE_DEMO_QUERIES_READ_ONLY.sql):
- Query 4: JOIN reports, resident profiles, categories and optional staff.
- Query 5: report counts by status.
- Query 10: RLS-enabled flags for the six application tables.

*Note:* The SQL Editor may run with privileged permissions, so the SELECT results alone **do not** demonstrate ordinary-user RLS. The negative access evidence comes from separate Auth sessions in integration tests.

## 6:35–7:35 | Evidence and honest conclusion

"Our work is documented in GitHub and checked by CI. The integrated Flutter tests, Flutter Web build, real Chrome role-workflow tests, PostgreSQL smoke tests and local Supabase API tests passed. The integrated Android APK and Flutter Web artifacts were also built successfully.

This is a tested release candidate, not a fully deployed production application. All twelve original implementation tasks are closed at **code and local-test acceptance level**. Hosted deployment and final project-specific verification are separately tracked in RELEASE GATE #47. Password recovery, push notifications and self-service role administration are not presented as complete.

Thank you. We are ready for questions and can demonstrate the SQL, architecture and automated tests."

**Show latest verified evidence:**
- [Integrated release — all jobs successful, Android APK and Flutter Web artifacts](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44963696769).
- [Integrated Flutter Web Chromium E2E](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44963696839).
- [Integrated PostgreSQL/Moderator smoke](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44963696859).
- [Local Supabase Auth/REST/Storage API integration](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44963622480).
- [Two-session atomic claim check](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44956576887).

## Common lecturer questions

**Why Flutter and Flutter Web?** We share a Flutter codebase and Supabase data model while presenting role-specific mobile and browser experiences. The earlier standalone HTML/JavaScript admin was a prototype, not the final selected Flutter Web operations deliverable.

**Why use Supabase?** Authentication, relational PostgreSQL, private photo Storage and policy-based authorization are integrated. We still keep SQL definitions and a rebuildable local backend to explain and test the design.

**Why Row Level Security (RLS)?** It protects data at the database level across different clients. Tests confirm cross-resident report/photo isolation and no direct role self-promotion.

**What is a protected RPC?** A PostgreSQL function exposed to the authenticated client that checks the user's role, ownership and report state before doing a permitted operation.

**How can only one employee claim a report?** The claim function uses an atomic conditional update. Our two-session concurrency test showed exactly one winner and one status-history record.

**Why are there two ERDs?** The current hosted database has six application tables. The Moderator review proposal introduces a seventh table; it is separately labelled until deployed and verified.

**Why can't we just run all migrations on production?** The hosted database already has the baseline schema but no recorded migration history. Reapplying the fresh baseline would collide with existing objects. We need a reviewed reconciliation and staged additive migration plan.

**Is the project completely finished?** The integrated MVP is tested locally and the APK/Web artifacts are built. Tasks #36 and #39 are implemented and tested locally, but the hosted release gate #47 is not completed, and some backlog features are beyond this tested scope.

## Lecturer handoff links

- [Integrated code and PR #46](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/46)
- [Lecturer review index](LECTURER_REVIEW_START_HERE.md)
- [Database Architecture](DATABASE_ARCHITECTURE.md)
- [Read-only SQL demonstration](sql/FIXMATE_DEMO_QUERIES_READ_ONLY.sql)
- [Task status and evidence](TASK_STATUS_RECONCILIATION.md)
- [Safe validation/Moderator rollout plan](CONTROLLED_SUPABASE_ROLLOUT_TASK36_TASK39.md)
- [Flutter Web operations setup](../mobile/OPERATIONS_WEB_README.md)

**Safety:** Never display real passwords or secret keys, and never run structural SQL on the populated hosted project for a classroom demonstration.
