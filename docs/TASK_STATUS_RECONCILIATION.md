# FixMate — Implementation Task Status Reconciliation

**Reviewed:** 21 November 2026  
**Source:** the 12 actual TASK issues in this repository (#30–#41), their individual acceptance criteria, the submitted Flutter/Admin code and verified Supabase/QA results.

> **Important:** GitHub Projects V2 `Status` is a separate field from the issue body and issue open/closed state. The issue descriptions and completion state were reconciled; this document is the intended **Project Board target mapping**. Do not claim that the Projects V2 field is synchronized until it has been checked in the board itself.

## Done (3)

| Task | Evidence / reason |
|---|---|
| [#31 — Resident maintenance report submission form](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/31) | Category, form validation, Supabase report creation, success/error handling implemented and exercised |
| [#32 — Flutter photo attachment](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/32) | Image selection and preview; JPEG/PNG/WebP validation; linked private Storage upload and error handling implemented and exercised |
| [#37 — Atomic staff claim and report status transitions](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/37) | Database function bodies verified; conditional atomic report update, role validation, persisted history with timestamps and denial of inappropriate roles |

These three verified issues were marked **closed/completed** in the issue tracker. Their associated Flutter/documentation PRs are still draft review items; completing a task does not itself merge a PR.

## In Progress (8)

| Task | Remaining acceptance item |
|---|---|
| [#30 — Flutter structure and authentication](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/30) | Supabase login/logout exist, but resident registration/sign-up not demonstrated |
| [#33 — My Reports and details](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/33) | List/details/RLS work; submitted date exists in model but is not displayed in report details UI |
| [#34 — Supabase database schema](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/34) | Tables and ERD implemented; complete version-controlled reproducible migrations and indexes not yet provided |
| [#35 — Auth profiles and RBAC](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/35) | Existing roles, RLS and direct role-update blocking verified; registration/profile provisioning and admin role management/provisioning documentation incomplete |
| [#36 — Maintenance report backend and Storage policies](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/36) | Report and photo flows work; remaining endpoint negative tests, invalid-field backend checks and upload error-path testing |
| [#38 — Flutter Web admin / role navigation](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/38) | Working standalone HTML/JS admin exists; the project team reports the lecturer approved this framework change on 21 Nov 2026. Task remains In Progress because the originally described staff/moderator navigation and acceptance checks are not fully demonstrated |
| [#40 — Staff queue and claim UI](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/40) | Queue/claim/conflict handling implemented in Flutter; original task is designated Admin Web, so delivery placement needs acceptance |
| [#41 — Staff status update UI](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/41) | Staff claim/resolve controls work in Flutter; last status-update timestamp display and designated web area remain incomplete |

## Backlog / To do (1)

- [#39 — Moderator review UI](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/39): no dedicated moderator review flow with duplicate/inappropriate outcomes persisted to backend has been demonstrated.

## Board synchronization and review

- The GitHub Project is [FixMate board #1](https://github.com/users/ahmedfak105/projects/1).
- Set the board `Status` field to **Done** for #31, #32, #37; **In Progress** for #30, #33, #34, #35, #36, #38, #40, #41; **Backlog** (or the board's equivalent `Todo`) for #39.
- Do not classify Features/Epics as complete automatically from these task statuses; check their own acceptance criteria.
- Avoid merging PRs #42/#43/#44 or closing any additional issues without review.
- The PowerShell script `FixMate_Update_Project_Board.ps1`, prepared separately for the project team, uses GitHub CLI to synchronize **only these 12 existing board issues**. It previews changes before applying.

**Review principle:** task status reflects the original issue's stated acceptance criteria, not merely the existence of some related code.


## Follow-up implementation evidence — 21 November 2026 (after original review)

The approved **Goals, Scope, and Acceptance Criteria in the individual GitHub TASK issues remain unchanged**. The team reported that the lecturer accepted standalone HTML/CSS/JavaScript as the Admin Web implementation technology in place of Flutter Web. The implementation still must satisfy role-specific features and backend rules.

| TASK | New code/evidence | Remaining verification |
|---|---|---|
| **#33 — My Reports & details** | Resident list and details now display the submitted date from `createdAt`, with English/Lithuanian labels; Flutter CI passed on commit `5b980a8` | Re-check resident ownership and UI against test Supabase in browser/mobile before closing |
| **#38 — Role-based Admin Web** | `admin-web/staff.html` and `staff.js` add a maintenance-staff-only web workspace; login redirects staff from Admin sign-in, with role guard on the staff page | Moderator-specific web navigation, live access checks for all roles and review workflow are outstanding |
| **#40 — Staff available queue & claim UI** | Staff Web now displays Available/My Jobs and calls role-checked `claim_maintenance_report` with conflict feedback and refresh | Test with real staff sessions, concurrent claims and role denials before closing |
| **#41 — Staff status update UI** | Staff Web includes Resolve action through `resolve_maintenance_report`; status-history update timestamp is shown when readable | Test live report transitions, latest timestamp and Resident status visibility before closing |
| **#39 — Moderator review UI** | Not yet implemented | Requires an approved/persisted review outcome for valid, duplicate and inappropriate reports, with photo visibility and role checks |

Admin Web static CI passed on commit `545e943`. These are **code-level progress updates**, not a declaration that the complete tasks are Done. The previous task classifications and Board field status should not be changed merely because code was committed.

## Moderator review implementation update — 21 Nov 2026 (follow-up)

**TASK #39 remains In Progress / not accepted.** The earlier "not implemented" note was a snapshot before this implementation.

- Moderator UI is now committed to PR #44: `admin-web/moderator.html`, `moderator.js`; main login redirects role `moderator` to its own web view.
- New, **not-yet-applied** migration in PR #42: [PROPOSED_MODERATOR_REVIEW_MIGRATION.sql](sql/PROPOSED_MODERATOR_REVIEW_MIGRATION.sql). It proposes `report_reviews`, a restricted review RPC, and a guard preventing claim/assignment of rejected reports.
- [Moderator staging test plan](MODERATOR_REVIEW_STAGING_TEST_PLAN.md) captures the role-based, photo, persisted-decision, concurrency and regression checks required for acceptance.
- **Not completed:** staging deployment, live browser/API tests, security verification, and lecturer/team review of database migration. Do **not** close TASK #39 or report it as Done yet.

This proposed change adds a seventh public table **only if deployed**; existing six-table documentation records the verified baseline and is not automatically updated.

## Resident registration progress — TASKS #30 and #35 (proposed, not deployed)

- Added `mobile/lib/features/auth/sign_up_page.dart`: email/password/confirmation and name + optional building/room; **no user-selectable role**. The Login screen exposes the signup link **only** when `ENABLE_RESIDENT_SIGNUP=true` is supplied at launch.
- Added `mobile/test/sign_up_page_test.dart` for local field validation and the absence of privileged role selection.
- Added [proposed resident Auth provisioning trigger](sql/PROPOSED_RESIDENT_SIGNUP_PROVISIONING.sql). It uses the new auth user's UUID and forces `role = 'resident'` regardless of metadata.
- The SQL has **not** been applied to Supabase. Leave signup disabled by default until trigger ownership, account creation, confirmation behavior and role isolation are tested in staging. Do not close #30/#35 yet.
- Existing trusted staff/moderator/admin profile provisioning remains separate; this trigger does not authorize assigning privileged roles.

## Live Supabase read-only verification — 22 November 2026 (supersedes proposed trigger)

Direct connector inspection of FixMate's **existing** Supabase project `epsvagztisdovixlqehi` found:
- **6** `auth.users`, **6** `public.profiles`, **0** users without profiles.
- `auth.users` already has `on_auth_user_created`, which calls `private.handle_new_user()`.
- `private.handle_new_user()` uses `SECURITY DEFINER`, empty `search_path`, inserts `NEW.id` and `full_name`, and forces `role='resident'` independently of user-editable metadata. Function owner is `postgres`.
- `authenticated` cannot directly INSERT profiles or UPDATE `profiles.role`.
- The signup UI no longer includes optional building/room fields because the existing trigger doesn't populate those fields. There is **no reason to install a duplicate auth trigger**.
- [Resident provisioning SQL](sql/PROPOSED_RESIDENT_SIGNUP_PROVISIONING.sql) has been replaced with a **read-only verification script**, retaining its original path to avoid broken review links.
- The default `ENABLE_RESIDENT_SIGNUP=false` stays in place until staging sign-up tests with a new user and confirmation flow pass. **TASKS #30 and #35 remain In Progress**, not Done.
- No Supabase DDL or data was changed by this verification.

For **TASK #39**, live catalog inspection confirmed `report_reviews` and `review_maintenance_report` are absent and no maintenance-report triggers exist. Proposed moderator migration has **not** been applied. No current `moderator` account was found (resident 3, staff 2, admin 1), so role-specific testing requires a test moderator in a separate environment.

**Database delivery caveat:** `list_migrations` returned zero tracked migrations and `list_branches` returned zero development branches. Do not claim a reproducible deployment or an existing staging database. The migration history and staging strategy need attention before task #34 can be Done.
