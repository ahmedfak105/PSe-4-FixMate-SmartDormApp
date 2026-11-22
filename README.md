> **Lecturer handoff updated 22 Nov 2026:** Use the [current 11-table lecturer handoff](docs/LECTURER_FINAL_HANDOFF_CURRENT_2026-11-22.md), [Mermaid ERD](docs/FIXMATE_HOSTED_ERD.md), and [FCM server activation checklist](docs/FCM_SERVER_FINAL_ACTIVATION_2026-11-22.md). The hosted `send-report-push` Edge Function is **ACTIVE**, but Firebase server secrets, automatic invocation and Android locked-screen delivery are **not yet confirmed**. [Release Gate #47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47) remains open.\n\n# FixMate – SmartDormApp

Dormitory maintenance reporting app with distinct **Resident**, **Maintenance Staff**, **Moderator**, and **System Admin** workflows, developed for Kauno Kolegija internal internship.

## One-repository integration candidate

This **integration branch** combines the code and documentation for lecturer review:

| What to review | Where |
|---|---|
| Resident/Staff Flutter app and Android build | [mobile/](mobile/) |
| Actual Flutter Web operations (Staff, Moderator, Admin) | [mobile/OPERATIONS_WEB_README.md](mobile/OPERATIONS_WEB_README.md) |
| Architecture & security | [docs/DATABASE_ARCHITECTURE.md](docs/DATABASE_ARCHITECTURE.md), [docs/DATABASE_RLS_SECURITY.md](docs/DATABASE_RLS_SECURITY.md) |
| ERD of original live six-table database | [docs/FIXMATE_ERD.md](docs/FIXMATE_ERD.md) |
| Separately proposed Moderator ERD | [docs/erd/FIXMATE_PROPOSED_MODERATOR_ERD.mmd](docs/erd/FIXMATE_PROPOSED_MODERATOR_ERD.mmd) |
| Fresh-database CLI migrations | [supabase/migrations/](supabase/migrations/) |
| Proposed validation and review SQL (not deployed live) | [docs/sql/PROPOSED_REPORT_INPUT_VALIDATION.sql](docs/sql/PROPOSED_REPORT_INPUT_VALIDATION.sql), [docs/sql/PROPOSED_MODERATOR_REVIEW_MIGRATION.sql](docs/sql/PROPOSED_MODERATOR_REVIEW_MIGRATION.sql) |
| Presentation & delivery checklist | [docs/LECTURER_PRESENTATION_SCRIPT.md](docs/LECTURER_PRESENTATION_SCRIPT.md), [docs/INTEGRATION_AND_DELIVERY_HANDOFF_2026-11-22.md](docs/INTEGRATION_AND_DELIVERY_HANDOFF_2026-11-22.md) |

**Start here for the lecturer:** [Lecturer Review Index](docs/LECTURER_REVIEW_START_HERE.md) and [Flutter Web operations guide](mobile/OPERATIONS_WEB_README.md).

## Build the applications

From `mobile/` using Flutter stable:

```bash
flutter pub get
flutter gen-l10n
flutter analyze --no-fatal-infos
flutter test
flutter run -d chrome --dart-define=FIXMATE_OPERATIONS_WEB=true
```

The last command launches Flutter Web Operations. Supply the **public** Supabase project URL and publishable/anon key in the connection form; the actual Moderator review workflow requires a *test database with the proposed review migration applied*. Do not enter `service_role` or `sb_secret_` keys in browser/client code.

For Resident/Staff mobile workflows, use Flutter without `FIXMATE_OPERATIONS_WEB=true`, configured with a valid public Supabase URL/key. Without a valid public Supabase URL/key, the app displays a connection-required screen and never shows synthetic reports.

## Build/test proof

GitHub Actions workflows under `.github/workflows/` validate the integrated Flutter app, Android APK, Flutter Web static bundle, reproducible local Supabase database, backend checks and browser workflows. The **integrated release workflow** produces separate Android and Flutter Web artifacts. Review the latest checks on the integration branch; checks on individual prior PR branches do not guarantee the combined commit.

## Deployment / review status

**This is a review candidate, not a production release.** The five versioned local migrations include report validation and Moderator review as additions to the original three baseline migrations. Use [the isolated integration-test runbook](docs/LOCAL_LECTURER_DEMO_RUNBOOK.md) only for developer QA; the installed app has no offline fixture mode. The active remote Supabase project contains six public application tables; its manually created schema must not be overwritten with the fresh database baseline migrations. The proposed new report validation and Moderator review SQL have passed isolated local tests but are **not deployed on the active project**. Do not claim that live Moderator review works until a separately approved staged rollout passes.

- All **12/12 original implementation TASKs** are closed at local code/CI acceptance level, including [#36](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/36) and [#39](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/39). **Hosted migration is NOT done**: [RELEASE GATE #47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47) tracks approved remote staging/backup/reconciliation.
- Previous source PRs: #42 (documentation/database), #43 (Flutter mobile), #45 (Flutter Web), with #44 an optional older HTML/JavaScript prototype. These remain subject to review.
- No private API keys, production credentials, actual resident data or passwords should be committed or included in screenshots.

**Do not merge this branch to `main` until the latest combined tests have passed and the team has reviewed the scope.**

## Isolated developer quality assurance (not part of the app)

Synthetic accounts and test records are restricted to local Supabase CLI tests
and `mobile/test/`. They are **never** loaded by the installed Android app
or Flutter Web. The [isolated API-test runbook](docs/LOCAL_LECTURER_DEMO_RUNBOOK.md)
explains how automated QA protects actual hosted data. The production UI
requires Supabase authentication for all four roles; unfinished hosted
capabilities remain blocked until approved under Release Gate #47.

## Final lecturer handoff index

[Current technical release status and sign-off gates](docs/FINAL_LECTURER_HANDOFF_STATUS.md) lists the **12 locally completed TASKs**, successful live-browser and API evidence, Android/Web build locations, the reproducible local test script, the remaining separate hosted deployment gate, and what the lecturer should review in PR #46.
