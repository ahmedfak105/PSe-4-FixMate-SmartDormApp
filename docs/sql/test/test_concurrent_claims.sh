#!/usr/bin/env bash
# TASK #37: two *simultaneous* authenticated staff claims on one report.
# Uses the disposable PostgreSQL 17 smoke service, NOT live Supabase.
set -euo pipefail
: "${PGHOST:?}" "${PGPORT:?}" "${PGUSER:?}" "${PGPASSWORD:?}" "${PGDATABASE:?}"

id2='00000000-0000-0000-0000-000000000006'
id1='00000000-0000-0000-0000-000000000003'
psql -X -q -v ON_ERROR_STOP=1 -c "
 INSERT INTO auth.users(id,raw_user_meta_data)
 VALUES ('$id2'::uuid, '{\"full_name\":\"Concurrency Staff Two\"}'::jsonb);
 UPDATE public.profiles SET role='maintenance_staff' WHERE id='$id2'::uuid;
" >/dev/null
rid="$(psql -X -qAt -v ON_ERROR_STOP=1 -c "
 INSERT INTO public.maintenance_reports
   (resident_id,category_id,title,description,location)
 SELECT '00000000-0000-0000-0000-000000000001'::uuid,
        id,'Concurrent claim race','Exactly one staff member may claim','Room 103'
 FROM public.maintenance_categories WHERE name='Plumbing'
 RETURNING id;
")"
[[ "$rid" =~ ^[0-9]+$ ]] || { echo "No valid race report ID" >&2; exit 1; }

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
claim_as() {
  local actor="$1"
  psql -X -qAt -v ON_ERROR_STOP=1 >"$2" 2>"$3" <<SQL
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = '$actor';
SELECT public.claim_maintenance_report($rid);
SELECT pg_sleep(0.7);
COMMIT;
SQL
}
claim_as "$id1" "$workdir/a.out" "$workdir/a.err" &
pid1=$!
claim_as "$id2" "$workdir/b.out" "$workdir/b.err" &
pid2=$!
wait "$pid1"
wait "$pid2"

one="$(grep -hEc '^t$' "$workdir/a.out" "$workdir/b.out" | awk '{sum+=$1}END{print sum+0}')"
zero="$(grep -hEc '^f$' "$workdir/a.out" "$workdir/b.out" | awk '{sum+=$1}END{print sum+0}')"
if [[ "$one" != "1" || "$zero" != "1" ]]; then
  echo "Race failed: expected exactly one successful and one failed claim" >&2
  cat "$workdir/a.err" "$workdir/b.err" >&2
  exit 1
fi

state="$(psql -X -qAt -v ON_ERROR_STOP=1 -c "
SELECT CASE WHEN r.status='in_progress'
 AND r.assigned_to IN ('$id1'::uuid, '$id2'::uuid)
 AND (SELECT count(*) FROM public.report_status_history h
      WHERE h.report_id=r.id AND h.new_status='in_progress')=1
 THEN 'ok' ELSE 'invalid' END
FROM public.maintenance_reports r WHERE r.id=$rid;
")"
[[ "$state" == "ok" ]] || { echo "Race state/history was not atomic: $state" >&2; exit 1; }
echo "PASS: concurrent claim yielded exactly one winner and one history row."
