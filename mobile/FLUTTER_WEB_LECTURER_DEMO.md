> **Current implementation acceptance — 22 Nov 2026:** The original **12/12 TASK issues are closed** following reproducible local Flutter/Supabase/API/Storage/Chrome tests. Five CLI-named migrations build a fresh local environment including report validation and Moderator review. **This is NOT hosted deployment or lecturer final sign-off.** The populated remote still has the original six application tables and empty migration history; [RELEASE GATE #47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47) tracks approved backup/staging/reconciliation/target-project deployment. [Integrated Draft PR #46](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/46) remains unmerged.

# FixMate — Flutter Web Operations Lecturer Demonstration

**Date:** 22 November 2026  
**Stack:** Flutter Web + Supabase Auth + PostgreSQL/RLS + Storage + role-checked RPC functions.  
**Scope:** This walkthrough demonstrates the explicitly required Flutter Web operations experience, separate from the Flutter Resident mobile build and the earlier standalone HTML/JavaScript dashboard.

## Preparation

1. Use **a separate, disposable Supabase CLI environment or an approved staging project** for the complete workflow. The live project has the original six-table schema; the seventh Moderator review table and review RPC have **not** been deployed there.
2. Confirm role-provisioned accounts are available for Resident, Maintenance Staff, Moderator and System Admin. Ordinary signup always creates a Resident, not a privileged user.
3. Open the Flutter Web operations build from the GitHub Actions artifact after serving it on an HTTP(S) origin, or run it locally:

       cd mobile
       flutter pub get
       flutter run -d chrome --dart-define=FIXMATE_OPERATIONS_WEB=true

   The runtime connection page asks for the shared Supabase URL and **publishable/anon** key. Do not enter a service-role or secret key.

4. Open the resident mobile build separately for report creation and final status verification.

## Speaking notes (English; ~7 minutes)

**0:00–0:45 — Architecture.**

> FixMate is a dormitory maintenance reporting system with role-based workflows. The Resident app and the Flutter Web operations dashboard share one Supabase database. Supabase Auth identifies users, RLS controls access to data, and PostgreSQL functions control the report assignment, claim, review and resolution actions. The client never uses a service-role key.

**0:45–1:40 — Authentication and role routing.**

> I will log in with the different test roles. Residents do not have access to the privileged operations workspace. Maintenance Staff, Moderators and System Admins are sent to distinct screens. These screens hide actions they cannot use, but access security is enforced by the backend, not by hiding buttons.

Show a Resident attempt being denied, then log in with System Admin.

**1:40–2:50 — System Admin.**

> The Admin dashboard displays real reports grouped by status, with categories and user assignments. The All Reports screen supports search. The Assignments screen allows an administrator to assign a New report to an existing Maintenance Staff account. Assignment leaves the report status New, because only the employee's Claim action starts work. The people directory is currently read-only; privileged role changes are intentionally managed by a trusted operator.

Assign an unclaimed, **valid** test report to a Maintenance Staff user.

**2:50–4:00 — Maintenance Staff.**

> The Staff dashboard shows an Available queue and My Jobs. Staff can claim an unassigned report or a New report preassigned to them. The atomic database function prevents two employees from claiming the same report. After Claim, the status becomes In Progress; the employee can resolve their own report, recording the Resolved state. The UI also shows the submitted date and latest status-update timestamp where permitted.

Log in as that employee; Claim the report; resolve it; show the status feedback.

**4:00–5:15 — Moderator and photos.**

> Moderators review new, unassigned submissions. They can inspect the description, category, location and private photo. They choose Valid, Duplicate or Inappropriate, with a required reason for rejected submissions. Decisions are written to a protected review record. Duplicate and Inappropriate submissions cannot later be claimed or assigned on the staging backend with the proposed guard installed.

Open the Moderator workspace, view a permitted photo, and review an unassigned report. Mention clearly that this workflow uses the **proposed review migration on disposable local/staging Supabase**, not the unchanged live project.

**5:15–6:15 — Security and verification.**

> We tested authorization with five separate synthetic Auth accounts, including negative role tests. An ordinary resident could not promote their own role, inspect another resident's report or private photo, or invoke the Moderator review RPC. We also tested two concurrent Staff claims and verified exactly one succeeded. Our GitHub Actions CI rebuilds the baseline from committed Supabase migrations on a clean disposable database.

Show:
- [Flutter Web build — latest tested code](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44961977303)
- [Real Flutter Web Chrome E2E — six passing role/workflow tests](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44961977375)
- [Supabase + Chromium HTML dashboard browser test](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44958916137)
- [Concurrent claim test](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44956576887)

**6:15–7:00 — Scope and current limitations.**

> The Flutter Web implementation is separated as draft PR #45 based on the Flutter Mobile PR. The database baseline is reproducible locally, but merging and staging deployment still require review. Password recovery, push notifications and fully self-service role administration are outside the completed MVP and are tracked separately. We are reporting these limits rather than presenting unfinished features as done.

## Test checklist before lecturer demonstration

- [x] Flutter Web release build and widget CI passed on the tested application code (22 November 2026).
- [x] The **actual Flutter Web** Chrome integration passed six Auth/Staff/Admin/Moderator scenarios on disposable local Supabase; this is not evidence of deployment.
- [x] Synthetic Resident, Staff, Moderator and Admin Auth sessions exercised in local Supabase, with Resident denied from Operations.
- [ ] Moderator review table/RPC are present on the isolated demo database.
- [ ] Test report is visible end-to-end from Resident submission through staff resolution.
- [ ] Private photo is accessible by an authorized reviewer and denied to another Resident.
- [ ] Avoid including private access keys, real resident records or passwords in screenshots.
- [ ] Record the lecturer's approval for any technology or acceptance changes in GitHub.

**Repository delivery:** [Draft PR #45](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/45) and the other unmerged feature/documentation PRs. **Do not use the production database for demonstration test writes.**

## Additional verified acceptance evidence

After fixing a narrow-screen Staff card overflow and moving Claim/Resolve confirmation to a visible SnackBar, [GitHub Actions 44961977375](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44961977375) passed **all six actual Flutter Web Chrome integration tests**: Resident denied, Admin dashboard visible, Staff Claim→Resolve saved, Moderator Valid review saved, Moderator Duplicate review with required reason saved, and Admin assignment leaving report New until Staff claims it. [Web release artifact 44961977303](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44961977303) and [Flutter CI 44961977318](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44961977318) passed on the same SHA.

All E2E accounts, photos and reports belonged to an isolated local Supabase test instance; Moderator review SQL has **not** been deployed to the remote original project. The GitHub PRs still await review/merge.
