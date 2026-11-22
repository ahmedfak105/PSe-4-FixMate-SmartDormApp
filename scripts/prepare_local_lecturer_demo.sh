#!/usr/bin/env bash
# FixMate — local-only lecturer demo bootstrap. Requires Docker and Supabase CLI.
# Resets ONLY the CLI database at 127.0.0.1:54322. Never points to hosted Supabase.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

for tool in docker supabase psql jq curl; do
  command -v "$tool" >/dev/null || { echo "Missing $tool" >&2; exit 1; }
done
docker info >/dev/null 2>&1 || {
  echo "Docker is not running." >&2; exit 1;
}
if [[ -n "${SUPABASE_DB_URL:-}" || -n "${DATABASE_URL:-}" || -n "${PGSERVICE:-}" ]]; then
  echo 'Refusing an externally configured remote database URL / PG service.' >&2; exit 1
fi
for variable in PGHOST PGPORT PGUSER PGDATABASE; do
  if [[ -n "${!variable:-}" ]]; then
    echo "Refusing preconfigured $variable: unset external database settings." >&2; exit 1
  fi
done

if [[ ! -f supabase/config.toml ]]; then
  supabase init
fi

echo 'Starting Supabase local Docker stack...'
supabase start
local_env="$(mktemp)"
trap 'rm -f "$local_env"' EXIT
supabase status -o env > "$local_env"
url="$(sed -n 's/^API_URL=//p' "$local_env" | tr -d '"')"
key="$(sed -n 's/^ANON_KEY=//p' "$local_env" | tr -d '"')"
if [[ "$url" != 'http://127.0.0.1:54321' && "$url" != 'http://localhost:54321' ]]; then
  echo "Refusing nonlocal API endpoint: $url" >&2; exit 1
fi
if [[ -z "$key" ]]; then
  echo 'No local public anon key was returned by Supabase CLI.' >&2; exit 1
fi

export PGHOST=127.0.0.1 PGPORT=54322 PGUSER=postgres
export PGPASSWORD=postgres PGDATABASE=postgres
export SUPABASE_URL="$url" SUPABASE_ANON_KEY="$key"
psql -X -qAt -v ON_ERROR_STOP=1 -c 'SELECT current_database();' >/dev/null

echo 'Restoring three committed migrations into disposable LOCAL Supabase...'
supabase db reset
echo 'Applying TASK #36 + TASK #39 proposed SQL in LOCAL stack only...'
psql -X -v ON_ERROR_STOP=1 -f docs/sql/PROPOSED_REPORT_INPUT_VALIDATION.sql >/dev/null
psql -X -v ON_ERROR_STOP=1 -f docs/sql/PROPOSED_MODERATOR_REVIEW_MIGRATION.sql >/dev/null
psql -X -v ON_ERROR_STOP=1 -c "NOTIFY pgrst, 'reload schema';" >/dev/null

echo 'Provisioning test-only roles, dummy reports, and photo permissions...'
bash docs/sql/test/local_supabase_api_smoke.sh

cat <<'END'

LOCAL FIXMATE DEMO READY
========================
Disposable role accounts (same LOCAL test password defined in
docs/sql/test/local_supabase_api_smoke.sh):
  resident.a.fixmate@example.com
  resident.b.fixmate@example.com
  staff.fixmate@example.com
  moderator.fixmate@example.com
  admin.fixmate@example.com

Flutter Web (Admin, Staff, Moderator):
  cd mobile
  flutter pub get
  flutter run -d chrome --dart-define=FIXMATE_OPERATIONS_WEB=true

On the Flutter Web connection form, enter:
  URL: http://127.0.0.1:54321
  Public anon key: 'supabase status -o env' → ANON_KEY (local only)

Resident/Staff connected browser build (on the same computer):
  flutter run -d chrome \
    --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
    --dart-define=SUPABASE_PUBLISHABLE_KEY=<LOCAL_ANON_KEY>

When finished:
  supabase stop --no-backup

Never paste a service-role/secret key into a Flutter browser app.
Never use the populated hosted project's database for demo writes.
END
