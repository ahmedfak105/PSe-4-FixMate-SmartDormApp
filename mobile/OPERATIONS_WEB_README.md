# FixMate Flutter Web Operations — Tasks #38–#41

**Scope:** This branch starts from the tested Flutter Mobile code and adds an **operations-only Flutter Web build**. The independent HTML/JavaScript dashboard in PR #44 is kept as a separate comparison/demo; it is not a replacement for the requested Flutter Web application.

## Role-specific screens

| Supabase Auth profile role | Mobile default | Flutter Web operations |
|---|---|---|
| resident | Reports, submit and details | Denied |
| maintenance_staff | Staff claim, resolve and notes | Staff claim, resolve and notes |
| moderator | Denied | Review Valid/Duplicate/Inappropriate, inspect private photos |
| system_admin | Denied | Dashboard, reports, assignment, read-only people |
| unknown | Denied | Denied |

An authenticated Supabase profile selects the screen. PostgreSQL RLS and authorized RPCs, not UI hiding, are the security boundary.

## Running the Flutter Web operations build

From the repository root with Flutter SDK installed:

    cd mobile
    flutter pub get
    flutter gen-l10n
    flutter run -d chrome --dart-define=FIXMATE_OPERATIONS_WEB=true --dart-define=SUPABASE_URL=https://YOUR_STAGING_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_KEY

To compile deployable web assets, replace flutter run with flutter build web --release and keep the same three dart-define values. Review hosting and routing configuration.

Never supply a service-role key or an sb_secret key in Flutter builds or commits. The anonymous/publishable key is public; authorization belongs to Auth, RLS and RPC checks.

The operations-only build does not start an offline demo when Supabase settings are absent, or when launched on an Android device. Resident registration is not available in the operations login. Maintenance, moderator and admin roles must be provisioned by a trusted operator.

The original Resident/Staff mobile application continues to run without the operations-only flag.

## Backend staging prerequisite

The original project contains six application tables. The proposed Moderator review feature adds a seventh table report_reviews and a review_maintenance_report RPC, currently exercised in local Supabase tests but not yet deployed to the real project. The Flutter Moderator page shows an explicit migration error when the backend does not contain these objects.

The existing assign_maintenance_report RPC leaves status New for staff to claim. Staff uses claim_maintenance_report then resolve_maintenance_report. Rejected submissions cannot be claimed when the proposed Moderator SQL guard is installed.

Do not deploy unreviewed migration scripts to the active Supabase project merely to make a UI test pass.

## Checks

    cd mobile
    flutter analyze --no-fatal-infos
    flutter test
    flutter build web --release --dart-define=FIXMATE_OPERATIONS_WEB=true --dart-define=SUPABASE_URL=https://ci-only-placeholder.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_ci_only_placeholder

CI placeholders check code compilation only; they do not represent a deployable connected demonstration. See .github/workflows/flutter-web-operations-build.yml.

## Outstanding acceptance

- Test Chrome with three distinct real staging users, confirming role routing, sign out, loading, error and empty states.
- Create, review, assign, claim and resolve a report across users. Confirm Resident sees the new status.
- Test a private photo for Moderator, and unauthorized access denial for another Resident.
- Test narrow screens, accessibility, and deployed base URL.
- Merge only after team/PR review, and do not push baseline migrations onto populated remote Supabase.

**Status:** New code is submitted for review on a separate branch. Production Supabase and main remain unchanged.
