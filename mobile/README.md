# FixMate Mobile — Resident Flutter starter (demo)

Adapted from **Kauno Kolegija / Tadas Bulis** `examples/mobile-skeleton`.
**This is an offline prototype and has NOT been validated with Flutter SDK yet.**

## Included
- Independent nested Navigator per tab + BottomTabsCubit from lecturer's skeleton
- Four tabs: Home, My Reports, New Report, Profile
- `ReportRepository` abstraction and `InMemoryReportRepository` with two demo reports
- Report list, details, form validation and creation (stored in memory only)
- Localization EN / LT using lecturer's `gen-l10n` pattern
- Widget tests for navigation, report details, and form validation

## NOT included
- Supabase connection, authentication, uploads, status update permissions, web admin
- Generated student Swagger client, student screens, production data

## Run on a computer with Flutter SDK >= 3.32 (Dart >= 3.8)
```bash
flutter doctor
flutter pub get
flutter gen-l10n
dart format lib test
flutter analyze
flutter test
flutter run
```

The original lecturer project provides platform configuration scripts; this starter retains Android/iOS platform directories, but builds are not verified in the present environment. If platform build files are missing, run `flutter create --platforms=android,ios .` *on a copy* after committing current files, and inspect generated changes before accepting them.

## Continuous integration

`.github/workflows/flutter-check.yml` runs `flutter analyze` and `flutter test` on GitHub Actions when this project is at the root of a repository. If stored in a subfolder, update the workflow to set `working-directory` accordingly. The workflow has not been run yet.

## Next implementation steps
1. Confirm local Flutter SDK, run tests and fix build issues.
2. Confirm Supabase schema and API exposure, table/column names and RLS policy behavior.
3. Implement `SupabaseReportRepository` without changing screens or cubit APIs.
4. Implement authenticated resident session and protected routes.
5. Add photo upload and report history; then staff/admin web separately.

**Security:** Never commit service-role keys, passwords or private secrets. Only use Supabase publishable/anon key in client code together with RLS.
