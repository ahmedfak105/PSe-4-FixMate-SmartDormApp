> **Current implementation acceptance — 22 Nov 2026:** The original **12/12 TASK issues are closed** following reproducible local Flutter/Supabase/API/Storage/Chrome tests. Five CLI-named migrations build a fresh local environment including report validation and Moderator review. **This is NOT hosted deployment or lecturer final sign-off.** The populated remote still has the original six application tables and empty migration history; [RELEASE GATE #47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47) tracks approved backup/staging/reconciliation/target-project deployment. [Integrated Draft PR #46](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/46) remains unmerged.

# FixMate — Lecturer Review: Start Here

**Kauno Kolegija • Internal Internship • 22 November 2026**  
**Project:** FixMate – SmartDormApp  
**Integration candidate:** [Draft PR #46](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/46)  
**Purpose:** Navigate the **actual integrated Flutter Mobile + Flutter Web project**, the original Supabase database model, and the latest automated evidence.

> The integrated source is on a **review branch**, not merged into `main`. Automated development checks have passed, but the hosted Supabase project still has its **original six application tables**. Report-validation changes and the seventh Moderator review table/RPC are **proposed only**, tested in isolated local Supabase, not deployed to the hosted database.

## 1. Open these first

| What the lecturer wants to inspect | Exact location |
|---|---|
| **Whole integrated app and documentation** | [PR #46](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/46) and [combined branch](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/tree/integration/lecturer-review-2026-11-22) |
| **Resident/Staff mobile source** | [mobile/lib/](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/tree/integration/lecturer-review-2026-11-22/mobile/lib) |
| **Flutter Web Admin, Moderator and Staff** | [Operations setup](../mobile/OPERATIONS_WEB_README.md) and [operations screens](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/tree/integration/lecturer-review-2026-11-22/mobile/lib/features/operations) |
| **Source-of-truth database ERD** | [Original six-table ERD](FIXMATE_ERD.md) |
| **Proposed Moderator schema extension** | [Separately labeled seventh-table ERD](erd/FIXMATE_PROPOSED_MODERATOR_ERD.mmd) |
| **Backend schema, security and migrations** | [Architecture](DATABASE_ARCHITECTURE.md), [RLS, RPC and Storage](DATABASE_RLS_SECURITY.md), [CLI migrations](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/tree/integration/lecturer-review-2026-11-22/supabase/migrations) |
| **Read-only SQL examples** | [Demonstration queries](sql/FIXMATE_DEMO_QUERIES_READ_ONLY.sql) |
| **English 7–9-minute spoken demonstration** | [Lecturer Presentation Script](LECTURER_PRESENTATION_SCRIPT.md) |
| **Remaining deployment tasks** | [Controlled rollout guide](CONTROLLED_SUPABASE_ROLLOUT_TASK36_TASK39.md) and [read-only preflight SQL](sql/REMOTE_ADDITIVE_PREDEPLOY_READ_ONLY.sql) |

The original, separately implemented HTML/CSS/JavaScript Admin dashboard is in [Draft PR #44](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/44), but the **integrated deliverable uses Flutter Web**. Some older evidence snapshot documents still describe the earlier HTML version; those sections are historical, not the current UI architecture.

## 2. Database architecture

The original hosted Supabase application has **six public tables**:
`profiles`, `maintenance_categories`, `maintenance_reports`,
`report_attachments`, `report_notes` and `report_status_history`.

Supabase `auth.users` manages login identities and an existing trigger creates a Resident profile. The `report-photos` bucket is private. Original **RLS is enabled for all six public tables**; the inspection recorded **13 public-table policies and 3 Storage policies**. Database RPCs implement authorized Claim, Resolve and Admin Assign behavior.

A separate proposed `report_reviews` table, restricted Moderator review RPC and rejected-report work guard were successfully tested in **disposable local Supabase**. They are **not** present in the original hosted Supabase project.

Five ordered migrations under `supabase/migrations/` reconstruct the **full local development schema**: the original baseline, eight maintenance categories, nine foreign-key indexes, validated report fields and a seventh Moderator review table/RPC. Do **not** apply those fresh-baseline scripts to the existing, populated hosted project, which has no recorded migration history.

## 3. Latest verified checks on the integrated code

| Test | Evidence | Result |
|---|---|---|
| Flutter analysis + widget/unit tests | [Flutter CI](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44963696849) | Passed |
| Flutter Web release build | [Web build](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44963696864) | Passed |
| Real Flutter Web Chromium role/workflow E2E, isolated Supabase | [Browser E2E](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44963696839) | Passed |
| PostgreSQL schema/review/validation smoke | [Database smoke](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44963696859) | Passed |
| Full local Supabase Auth/REST/Storage API tests | [Local API integration](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44963622480) | Passed on earlier integration SHA |
| Integrated Android debug APK + Web bundle | [Combined release run](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44963696769) | All jobs passed; both artifacts uploaded |
| Two simultaneous staff claims | [Concurrency test](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44956576887) | Exactly one winner |

A later **documentation-only** change refreshed the presentation script; its new CI rerun may still be in progress. The app-source build evidence above is from the last checked integrated code SHA. Verify the newest run before merging.

**Artifacts:** Open the Combined Release run → **Artifacts** → `fixmate-integrated-android-debug-apk` or `fixmate-integrated-flutter-web-operations`. Files have limited retention and need suitable Android/Web installation or hosting for a live demo.

## 4. What to demonstrate in 7–9 minutes

1. **Problem and architecture:** show Flutter Mobile, Flutter Web, Supabase Auth/PostgreSQL/Storage and the ERD.
2. **Resident:** sign in, submit a dummy report, optionally attach a photo, open My Reports and details.
3. **Admin:** sign in to Flutter Web, show overview/report search, assign an eligible New report.
4. **Staff:** Claim the report, then Resolve it; show the status update and history.
5. **Moderator — isolated local/staging only:** open a private test photo and save a Valid/Duplicate/Inappropriate review with required rejection reason.
6. **Security/SQL:** show a report JOIN, status counts and RLS flags using read-only SQL; show successful local Auth/API role-denial tests, not just SQL Editor output.
7. **Conclusion:** show CI and the two remaining hosted-backend acceptance tasks.

Use **synthetic accounts and reports only**. Do not show real user records, private tokens, passwords or service-role keys.

## 5. Task, feature and release status

The implementation backlog tracks **12 original Tasks**; **all 12 are closed at implementation/local-test acceptance level**. [Task #36](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/36) and [Task #39](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/39) have accepted local Supabase/Flutter evidence, but their proposed changes have **not** been deployed on the hosted project. The remaining hosted rollout is tracked separately in **[RELEASE GATE #47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47)**, not silently counted as complete.

The wider Product Backlog includes **6 Epics / 22 Features**; closing the 12 implementation tasks **does not** mean every feature, such as push notifications, password recovery and full role self-administration, is complete. GitHub Project board Status fields may need separate review and synchronization with issue states.

PRs #42 (docs/backend), #43 (Flutter Mobile), #45 (Flutter Web) and #46 (combined integration) remain under review; PR #44 is the older optional HTML prototype. **No merge into `main` or new hosted database migration is claimed here.**

## 6. Questions and submission

For lecturer Q&A about RLS, SECURITY DEFINER, staff claims, SQL JOINs, category constraints and the distinction between local tests and hosted deployment, use the [updated presentation script](LECTURER_PRESENTATION_SCRIPT.md).

For safe release approval, use the [integration and delivery handoff](INTEGRATION_AND_DELIVERY_HANDOFF_2026-11-22.md) and the [controlled Supabase rollout checklist](CONTROLLED_SUPABASE_ROLLOUT_TASK36_TASK39.md). Do not push fresh-baseline migrations into the populated hosted project.

## Local lecturer demo that does not touch production

Use the [local four-role demonstration guide](LOCAL_LECTURER_DEMO_RUNBOOK.md) with the [bootstrap script](../scripts/prepare_local_lecturer_demo.sh). The script resets a **local-only** Supabase CLI database and creates five fictional accounts with sample reports/photos. This is the recommended way to show Moderator decisions without changing the hosted project's six-table database. It needs a computer running Docker; the GitHub Android/Web artifacts are build outputs, not standalone deployed backends.

