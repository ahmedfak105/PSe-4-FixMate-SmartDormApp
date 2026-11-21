# FixMate – SmartDormApp | Flutter Resident & Maintenance Staff MVP

This Flutter application is part of the Kauno Kolegija Internal Internship **FixMate – SmartDormApp** project. It provides resident maintenance-reporting and maintenance-staff workflows against the shared Supabase backend.

**MVP, not a production release.** The app can run in either authenticated Supabase mode or an offline, in-memory demo mode. The separate administrator interface lives in `admin-web/` on its own pull-request branch.

## Implemented scope

- Email/password **sign-in and sign-out** for existing Supabase Auth accounts, with profile-based routing.
- **Resident:** submit reports with active maintenance categories; view own reports and report details; upload/download report photos from private Supabase Storage.
- **Maintenance staff:** view eligible reports and assigned jobs; claim reports; resolve assigned in-progress reports; read/write internal maintenance notes.
- **Localization:** English and Lithuanian.
- Repository abstractions and Flutter tests. Supabase Row Level Security (RLS) and restricted database functions enforce backend authorization; hiding UI buttons alone is not a security boundary.

**Not implemented in this checked-in mobile build:** resident sign-up, password recovery, moderator workflows, push/status-change notifications, complete profile editing, and an in-app admin dashboard. The standalone admin website provides its own admin-only views.

## Prerequisites

- Flutter SDK with Dart **3.8 or later** (check with `flutter doctor`).
- For connected mode: a configured Supabase project with the FixMate schema, RLS policies, authenticated test accounts and a `profiles` row for each account.
- A **publishable/anon API key**, never a service-role or `sb_secret_` key. The public project URL and publishable key are provided at launch time.

## Run the authenticated application

From the repository root:

```bash
cd mobile
flutter pub get
flutter gen-l10n
flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Use an existing resident or maintenance-staff account at the sign-in screen. The app loads the account's role from `profiles`.

If your Chrome device has a different Flutter device name, run `flutter devices` first. Android and iOS project files are included, but a successful mobile-device build is **not** claimed in this repository.

## Run the offline demonstration

```bash
cd mobile
flutter pub get
flutter gen-l10n
flutter run -d chrome
```

With no Supabase dart-defines the app uses `InMemoryReportRepository` and displays a **DEMO DATA** banner. Demo changes do not persist to PostgreSQL.

## Checks

```bash
cd mobile
flutter pub get
flutter gen-l10n
flutter analyze --no-fatal-infos
flutter test
```

**Recorded evidence (21 Nov 2026):** 19/19 Flutter tests passed in the cloned repository and GitHub Actions succeeded on the `feature/flutter-resident-staff` branch. The analyzer reported informational notices, so CI permits those notices; this is not a clean-analyzer or full device-test claim. Re-run checks after subsequent code changes or merging.

## Relevant source files

- `lib/main.dart`: Supabase configuration via `--dart-define`, or offline demo fallback.
- `lib/features/auth/`: existing-account sign-in, profile/session gating.
- `lib/features/reports/`: submission, list and details UI.
- `lib/features/staff/`: staff queue, claim/resolve and internal notes.
- `lib/data/repositories/`: in-memory and Supabase implementations.
- `test/`: checked-in model and widget tests.

## Security and known limitations

- Use **test users and test records** for demonstrations. Never commit passwords, access tokens or server-side secrets.
- The backend must enforce ownership and role permissions using Supabase RLS and authorized RPC functions.
- The app currently expects previously provisioned Auth accounts and profiles; it does not create accounts.
- Report submission dates are not yet visible in every resident list/details view; some acceptance criteria and negative API/security tests remain outstanding.
- A reproducible end-to-end database migration is not included in this Flutter folder. For database architecture, ERD, SQL reference, read-only demo queries and security evidence, refer to the separate documentation PR.

This README supersedes the early offline-starter description. `README_APPLY_FIRST.txt` is an older staff-notes patch instruction, not a mandatory fresh-install workflow; consult the database/security documentation before changing live SQL grants.
