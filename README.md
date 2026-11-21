# FixMate – SmartDormApp

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

**Start here for the lecturer:** [Lecturer Review Index](docs/LECTURER_REVIEW_START_HERE.md) and [Flutter Web demo guide](mobile/FLUTTER_WEB_LECTURER_DEMO.md).

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

For Resident/Staff mobile workflows, use Flutter without `FIXMATE_OPERATIONS_WEB=true`, configured with a valid public Supabase URL/key. Without Supabase, the original mobile build has a local demo fallback and does not represent connected data.

## Build/test proof

GitHub Actions workflows under `.github/workflows/` validate the integrated Flutter app, Android APK, Flutter Web static bundle, reproducible local Supabase database, backend checks and browser workflows. The **integrated release workflow** produces separate Android and Flutter Web artifacts. Review the latest checks on the integration branch; checks on individual prior PR branches do not guarantee the combined commit.

## Deployment / review status

**This is a review candidate, not a production release.** The active remote Supabase project contains six public application tables; its manually created schema must not be overwritten with the fresh database baseline migrations. The proposed new report validation and Moderator review SQL have passed isolated local tests but are **not deployed on the active project**. Do not claim that live Moderator review works until a separately approved staged rollout passes.

- GitHub issues **#36** (report input validation backend) and **#39** (Moderator review live rollout) remain in progress.
- Previous source PRs: #42 (documentation/database), #43 (Flutter mobile), #45 (Flutter Web), with #44 an optional older HTML/JavaScript prototype. These remain subject to review.
- No private API keys, production credentials, actual resident data or passwords should be committed or included in demo screenshots.

**Do not merge this branch to `main` until the latest combined tests have passed and the team has reviewed the scope.**
