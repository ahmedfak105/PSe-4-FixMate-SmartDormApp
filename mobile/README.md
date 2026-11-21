# FixMate – SmartDormApp | Flutter Resident & Maintenance Staff MVP

This Flutter application is part of the Kauno Kolegija Internal Internship **FixMate – SmartDormApp** project. It provides resident maintenance-reporting and maintenance-staff workflows against the shared Supabase backend.

**MVP, not a production release.** The app can run in either authenticated Supabase mode or an offline, in-memory demo mode. The separate administrator interface lives in `admin-web/` on its own pull-request branch.

## Implemented scope

- Email/password **sign-in and sign-out** for existing Supabase Auth accounts, with profile-based routing.
- **Resident registration:** sign-up page is now visible by default in connected mode after passing isolated local Supabase Auth/API integration. New accounts always receive Resident role from the backend. To disable the UI where public registration is not wanted, pass `--dart-define=ENABLE_RESIDENT_SIGNUP=false`.
- **Resident:** submit reports with active maintenance categories; view own reports and report details; upload/download report photos from private Supabase Storage.
- **Maintenance staff:** view eligible reports and assigned jobs; claim reports; resolve assigned in-progress reports; read/write internal maintenance notes.
- **Localization:** English and Lithuanian.
- Repository abstractions and Flutter tests. Supabase Row Level Security (RLS) and restricted database functions enforce backend authorization; hiding UI buttons alone is not a security boundary.

**Still pending:** device/browser manual verification of this newly enabled signup screen against the team's real Supabase project and confirmation-email configuration. Password recovery, mobile moderator workflows, push/status-change notifications, complete profile editing and an in-app admin dashboard are not implemented. The standalone admin website includes separate staff/moderator/admin pages.

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

### Resident registration — locally API-tested, enabled in connected Flutter

The sign-up page is **on by default** for the connected Flutter application. A `--dart-define=ENABLE_RESIDENT_SIGNUP=false` override can hide it in deployments where sign-up is intentionally disabled. Direct inspection of the Supabase project on **22 Nov 2026** confirmed the pre-existing `auth.users` trigger `on_auth_user_created` calls `private.handle_new_user()`. It inserts `public.profiles` with the real Auth user ID, user-provided `full_name`, and **hard-coded `role='resident'`**. Database grants disallow direct `authenticated` updates to `profiles.role`. The project then had 6 Auth users and 6 corresponding profiles, with zero missing profiles.

**No new signup trigger should be installed.** The earlier redundant SQL proposal was replaced by the read-only [Existing Signup Trigger Verification](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/blob/docs/security-qa-evidence-2026-11-21/docs/sql/PROPOSED_RESIDENT_SIGNUP_PROVISIONING.sql). The registration form intentionally collects only email, password, and full name; building/room fields were removed because the existing trigger does not persist them. Building/room can be added later through approved profile editing.

**Verified in isolated local Supabase (22 Nov 2026):** GitHub Actions created fresh Auth users, confirmed an injected privileged `role` in signup metadata still produces a Resident profile, signed in through the real Auth API and tested report ownership and role-protected RPCs. [Passing local Supabase API integration run](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44956442908). **Remaining:** manually verify the actual Flutter sign-up screen with the project's real Auth settings, particularly email confirmation, duplicate signup behavior and rate limiting.

```bash
flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_KEY
```

To hide the signup button on a deployment that does not allow new accounts, add `--dart-define=ENABLE_RESIDENT_SIGNUP=false`. This flag affects the Flutter UI only; real access control remains in Supabase Auth, RLS and protected RPCs.

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
- `lib/features/auth/`: sign-in, registration form (feature-flagged), and profile/session gating.
- `lib/features/reports/`: submission, list and details UI.
- `lib/features/staff/`: staff queue, claim/resolve and internal notes.
- `lib/data/repositories/`: in-memory and Supabase implementations.
- `test/`: checked-in model and widget tests.

## Security and known limitations

- Use **test users and test records** for demonstrations. Never commit passwords, access tokens or server-side secrets.
- The backend must enforce ownership and role permissions using Supabase RLS and authorized RPC functions.
- The app can create new Resident Auth accounts and relies on the existing Auth-to-profile trigger for roles. Staff, Moderator and Admin accounts still require trusted operator provisioning.
- Report submission dates are now shown in resident list/details views. Negative role/RLS checks passed in local Supabase API integration; mobile-device testing and live deployment checks remain outstanding.
- A reproducible end-to-end database migration is not included in this Flutter folder. For database architecture, ERD, SQL reference, read-only demo queries and security evidence, refer to the separate documentation PR.

This README supersedes the early offline-starter description. `README_APPLY_FIRST.txt` is an older staff-notes patch instruction, not a mandatory fresh-install workflow; consult the database/security documentation before changing live SQL grants.
