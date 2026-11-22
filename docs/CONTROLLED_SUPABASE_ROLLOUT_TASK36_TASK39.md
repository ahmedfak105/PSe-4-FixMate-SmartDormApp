> **Current implementation acceptance — 22 Nov 2026:** The original **12/12 TASK issues are closed** following reproducible local Flutter/Supabase/API/Storage/Chrome tests. Five CLI-named migrations build a fresh local environment including report validation and Moderator review. **This is NOT hosted deployment or lecturer final sign-off.** The populated remote still has the original six application tables and empty migration history; [RELEASE GATE #47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47) tracks approved backup/staging/reconciliation/target-project deployment. [Integrated Draft PR #46](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/46) remains unmerged.

# TASK #36 and #39 — Controlled, additive Supabase rollout

**Status: staging-only proposal; NOT permission to modify the current project.**
Owner: FixMate team. Updated 22 November 2026.

## What is already verified

- An actual local Supabase CLI + Docker stack rebuilt the six-table baseline and applied the **proposed** report-validation and Moderator SQL, then authenticated synthetic Resident, Staff, Moderator and Admin users through the real Auth/Data/Storage APIs.
- [Full Flutter Web browser acceptance](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44962305056) passed on local Supabase. [Web bundle build](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44962305085) and [Flutter tests](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44962305057) passed for the same code commit.
- Read-only inspection of the **existing** Supabase project on 22 November 2026: **5 reports**, **0 incompatible report fields**, **0 reports referencing inactive categories**, **one** Resident INSERT policy, **zero** installed report_reviews tables, **zero** public review_maintenance_report RPCs, and **zero** rejection triggers. Its migration history is still **empty**. The remote project's current schema was not modified.
- This does **not** prove remote deployment safety. The Auth configuration, deployment grants, available database backup, staff role account and hosting should all be explicitly checked.

## Rule 1: never replay baseline into the already populated remote project

The existing project already has profiles, maintenance_categories, maintenance_reports, report_attachments, report_notes and report_status_history. The versioned baseline in supabase/migrations is for **fresh local/staging databases**. Running a standard **db push** with an empty remote migration history may attempt to recreate tables, triggers, policies and buckets already present.

**Do not** repair this by dropping live objects or marking random migrations as applied. First obtain a database backup/restore plan, compare exact remote schema and migration history, agree a proper baseline reconciliation approach and review it with the team. No command in this document automatically performs that reconciliation.

## Gate A — Read-only inspection

1. Confirm the correct database/project and access level. In the active project, run [REMOTE_ADDITIVE_PREDEPLOY_READ_ONLY.sql](sql/REMOTE_ADDITIVE_PREDEPLOY_READ_ONLY.sql); archive its output with the change ticket. This is a read-only file.
2. Confirm there are no incompatible existing report values. Also check whether the existing Resident INSERT policy differs from the captured draft, whether any review table/function/trigger already exists, and whether a different system has added reporting constraints.
3. Confirm a recent recoverable database backup and a successfully tested restore process. Confirm who has permission to authorize/apply changes. Do not treat a dashboard backup-status indicator as proof that restore works.
4. Confirm the target has the same Supabase Auth/Storage/API configurations needed by the app. Run Supabase Security/Performance advisors and review privileged SECURITY DEFINER functions.
5. If any unexpected object or policy exists, **stop** and reconcile it before proceeding.

## Gate B — Approved staging trial

Use an independent staging/clone database authorized by the project owner; do not copy real user accounts, sessions, test photos or credentials without explicit governance approval.

1. Create a fresh staging database from the existing baseline *or* restore a sanitized schema. If restoring the existing system, reconcile its migration history before adding change scripts.
2. Apply [PROPOSED_REPORT_INPUT_VALIDATION.sql](sql/PROPOSED_REPORT_INPUT_VALIDATION.sql) first. This adds three CHECK constraints and amends the existing Resident INSERT RLS policy to require an active category.
3. Using genuine **staging Auth user sessions** (not a privileged SQL Editor), test valid and invalid report creation and confirm meaningful Flutter error messages. A blank title, description, location, overlong title, inactive category, forged owner and Staff attempting to submit must all be rejected.
4. Apply [PROPOSED_MODERATOR_REVIEW_MIGRATION.sql](sql/PROPOSED_MODERATOR_REVIEW_MIGRATION.sql) next. It creates report_reviews, a restricted review RPC and an UPDATE trigger that blocks assignment/claim of rejected reports.
5. Verify Moderator Valid/Duplicate/Inappropriate flows, required reason, immutable decision, Admin-assigned New report, atomic Staff Claim then Resolve, status history, image privacy and unauthorized-role denial. Check that the Data API can access the new table through the intended grants and RLS.
6. Run the full Flutter Web Chromium acceptance suite and local Auth/REST/Storage suite as regression gates. Capture exact commit SHA, SQL script checksums, reviewer approval and screenshots.

## Gate C — Live go/no-go

Require **all** of the following before scheduling a remote change: approved change window, working recent backup and restore, verified staging tests with exact scripts, confirmed Auth/Storage/Data API settings, team review, and a verified migration-history reconciliation plan. If any requirement is missing, do not deploy.

Deploy only the reviewed **additive** changes in the order tested, using the approved mechanism. Do not combine them with the six-table baseline. Do not edit existing user roles, disable RLS, publish report photos, or add browser-side service-role keys.

Immediately after deployment: run the same read-only preflight inventory; expected review table/RPC/trigger counts should now be **one each**. Confirm every existing report still displays and that new report submission, Admin assignment, Moderator review and Staff workflow pass with authorized accounts. Capture the exact live deployment revision in GitHub and verify the Supabase advisors.

## Failure handling / rollback policy

There is **no universal safe automatic rollback** for the Moderator migration once people have submitted reviews. Dropping report_reviews would destroy audit decisions and the protective rejection trigger; rolling it back while leaving rejected reports might allow incorrect work assignment.

- Before accepting any Moderator writes, a failed staging or deployment smoke test can be handled with an approved database restore or carefully reviewed compensating change, using the predeployment backup.
- After reviews exist, **stop the Moderator UI / new-review workflow** on the affected deployment, preserve the moderation records and logs, and apply a reviewed **forward fix** rather than dropping tables or disabling RLS. Coordinate resolution with the database owner.
- Reverting report-input constraints may admit invalid future reports. Prefer a targeted correction after verifying existing data, ownership rules and INSERT policy; never relax role checks merely to make submissions pass.
- A failed deployment must be recorded explicitly; do not mark Tasks #36 or #39 Done based on local test results alone.

## Evidence for lecturer

Demonstrate: (1) real schema and ERD, (2) clean CLI rebuild and role/RLS tests, (3) successful Flutter Web browser workflow and APK/Web builds, (4) the preflight inventory showing why remote deployment is **still a separate gate**, and (5) the exact scripts that implement the missing features.

**Current distinction:** Original TASK #36 and #39 issues are closed after implementation and **local acceptance**. This does NOT mean the SQL is deployed to the original hosted project. All hosted/staging verification, backup/restore and release approval requirements remain open in [RELEASE GATE #47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47). The Flutter Web feature tests passing locally does not mean the review RPC exists on the original live project.

## Latest remote advisor snapshot — read-only, 22 November 2026

Running Supabase's advisors on the **existing** remote project returned:

- **Security WARN:** Leaked Password Protection is disabled. This is an Auth configuration decision requiring project-owner review; no setting was modified. [Supabase password protection guide](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
- **Performance INFO:** 9 unindexed foreign keys. Nine dedicated indexes already exist in the fresh-database migration set and have local-rebuild test evidence; they have **not** been pushed into the existing remote database. [Foreign key index advisor](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys).
- **Performance WARN:** 3 cases of multiple permissive SELECT RLS policies on `maintenance_reports`, `profiles` and `report_attachments`. These are potential performance optimizations, **not proof of an authorization bypass**. Do not combine/remove them without preserving each role's allowed rows and rerunning negative RLS tests. [Multiple permissive policies advisor](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies).

The advisor snapshot is an audit finding, not a blocker automatically fixed by this documentation. These settings and performance improvements need separate review and approval; never weaken RLS just to clear a warning.
