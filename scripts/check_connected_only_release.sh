#!/usr/bin/env bash
# FixMate connected-only release gate.
# Fail fast if a future change re-introduces an offline Demo/fake report
# path into the installed Flutter application or its Android release jobs.
set -euo pipefail
cd "$(dirname "$0")/.."

test -f mobile/lib/main.dart
test -f mobile/lib/app.dart
test -f mobile/lib/startup_mode.dart
test -f mobile/lib/data/repositories/report_repository.dart
test -f mobile/test/support/test_report_repository.dart

# Keep isolated synthetic test fixtures in test/ only; never ship them in lib/.
bad='FIXMATE_OFFLINE_DEMO|DEMO DATA|InMemoryReportRepository|demoNotice|reportCreatedDemo|demoResident|class TestReportRepository'
if grep -RInE "$bad" mobile/lib --include='*.dart' --include='*.arb'; then
  echo 'ERROR: A Demo path or in-memory test fixture reached production Flutter source.' >&2
  exit 1
fi

# Every published Android APK must be built with a public Supabase connection.
for workflow in \
  .github/workflows/integrated-release.yml \
  .github/workflows/flutter-android-build.yml \
  .github/workflows/flutter-android-connected-build.yml; do
  test -f "$workflow"
  grep -q 'SUPABASE_URL' "$workflow" || {
    echo "ERROR: $workflow lacks a hosted Supabase URL" >&2; exit 1;
  }
  grep -q 'SUPABASE_PUBLISHABLE_KEY' "$workflow" || {
    echo "ERROR: $workflow lacks a public Supabase key" >&2; exit 1;
  }
  if grep -qE 'FIXMATE_OFFLINE_DEMO|debug-demo|offline-demo|integrated-android-debug-apk' "$workflow"; then
    echo "ERROR: $workflow still includes a Demo APK build or artifact" >&2
    exit 1
  fi
done

# Missing connected credentials must not fall through to fake data.
grep -q "FixMateStartupMode.connectionRequired" mobile/lib/main.dart
grep -q "requireLogin: true" mobile/lib/main.dart
grep -q "FixMateStartupMode.connectionRequired" mobile/lib/startup_mode.dart

echo 'PASS: FixMate release ships only Supabase-connected Flutter, with test fixtures isolated.'
