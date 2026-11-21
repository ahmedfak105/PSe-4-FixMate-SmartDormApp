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
| [#38 — Flutter Web admin / role navigation](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/38) | Working standalone HTML/JS admin exists but does not meet the originally specified Flutter Web + staff/moderator navigation scope; seek lecturer approval for changed approach |
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
