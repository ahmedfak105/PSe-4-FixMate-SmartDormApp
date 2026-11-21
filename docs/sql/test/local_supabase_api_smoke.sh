#!/usr/bin/env bash
# TASK #30/#35/#36/#37/#39 — local Supabase API integration smoke.
# RUN ONLY against an isolated Supabase CLI stack.
# Never point SUPABASE_URL or PGHOST/PGPORT at the real FixMate project.
set -euo pipefail
: "${SUPABASE_URL:?Set local SUPABASE_URL}"
: "${SUPABASE_ANON_KEY:?Set local publishable/anon key}"
if [[ "$SUPABASE_URL" != "http://127.0.0.1:54321" && "$SUPABASE_URL" != "http://localhost:54321" ]]; then
  echo "Refusing nonlocal Supabase API target: $SUPABASE_URL" >&2; exit 1
fi
if [[ "${PGHOST:-}" != "127.0.0.1" || "${PGPORT:-}" != "54322" ]]; then
  echo "Refusing nonlocal PostgreSQL target" >&2; exit 1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
rest="$SUPABASE_URL/rest/v1"
auth="$SUPABASE_URL/auth/v1"
storage="$SUPABASE_URL/storage/v1"
password='LocalSmoke-Only-Password-2026!'

post_json() {
  local url="$1" token="$2" payload="$3"
  curl -fsS --max-time 20 -X POST "$url" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' \
    -H 'Prefer: return=representation' \
    --data "$payload"
}
signup() {
  local email="$1" name="$2" role_hint="$3"
  local body
  body="$(jq -nc --arg email "$email" --arg pwd "$password" --arg name "$name" --arg role "$role_hint" \
    '{email:$email,password:$pwd,data:{full_name:$name,role:$role}}')"
  local response
  response="$(curl -fsS --max-time 30 -X POST "$auth/signup" \
    -H "apikey: $SUPABASE_ANON_KEY" -H 'Content-Type: application/json' --data "$body")"
  echo "$response" | jq -er '.user.id // .id'
}
login() {
  local email="$1"
  local payload
  payload="$(jq -nc --arg email "$email" --arg pwd "$password" '{email:$email,password:$pwd}')"
  curl -fsS --max-time 30 -X POST "$auth/token?grant_type=password" \
    -H "apikey: $SUPABASE_ANON_KEY" -H 'Content-Type: application/json' --data "$payload" \
    | jq -er '.access_token'
}
validate_uuid() {
  [[ "$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] || {
    echo "Unexpected signup identifier" >&2; exit 1;
  }
}
role_promote() {
  local id="$1" role="$2"
  validate_uuid "$id"
  [[ "$role" == "maintenance_staff" || "$role" == "moderator" || "$role" == "system_admin" ]] || exit 1
  psql -X -q -v ON_ERROR_STOP=1 -c "UPDATE public.profiles SET role='$role' WHERE id='$id'::uuid AND role='resident';" >/dev/null
}
get_json() {
  local url="$1" token="$2"
  curl -fsS --max-time 20 "$url" \
    -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $token"
}
status_code() {
  local method="$1" url="$2" token="$3" data="${4:-}"
  if [[ "$method" == "POST" ]]; then
    curl -sS --max-time 20 -o "$workdir/error_response" -w '%{http_code}' \
      -X POST "$url" -H "apikey: $SUPABASE_ANON_KEY" \
      -H "Authorization: Bearer $token" -H 'Content-Type: application/json' --data "$data"
  else
    curl -sS --max-time 20 -o "$workdir/error_response" -w '%{http_code}' \
      "$url" -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $token"
  fi
}

# All identities and passwords are synthetic, created only inside this
# disposable Supabase instance. No real user or public app data is accessed.
a_email="resident.a.fixmate@example.com"
b_email="resident.b.fixmate@example.com"
staff_email="staff.fixmate@example.com"
moderator_email="moderator.fixmate@example.com"
admin_email="admin.fixmate@example.com"
a="$(signup "$a_email" "Test Resident A" "system_admin")"
b="$(signup "$b_email" "Test Resident B" "maintenance_staff")"
staff_id="$(signup "$staff_email" "Test Staff" "resident")"
moderator_id="$(signup "$moderator_email" "Test Moderator" "resident")"
admin_id="$(signup "$admin_email" "Test Admin" "resident")"
for id in "$a" "$b" "$staff_id" "$moderator_id" "$admin_id"; do validate_uuid "$id"; done

role_promote "$staff_id" maintenance_staff
role_promote "$moderator_id" moderator
role_promote "$admin_id" system_admin

a_token="$(login "$a_email")"
b_token="$(login "$b_email")"
staff_token="$(login "$staff_email")"
moderator_token="$(login "$moderator_email")"
admin_token="$(login "$admin_email")"

# Auth-to-profile trigger always creates Resident from untrusted signup metadata.
a_profile="$(get_json "$rest/profiles?select=id,role&id=eq.$a" "$a_token")"
echo "$a_profile" | jq -e --arg id "$a" 'length == 1 and .[0].id==$id and .[0].role=="resident"' >/dev/null

# A Resident must not elevate profiles.role through the actual REST API.
status="$(curl -sS --max-time 20 -o "$workdir/error_response" -w '%{http_code}' \
  -X PATCH "$rest/profiles?id=eq.$a" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $a_token" \
  -H 'Content-Type: application/json' --data '{"role":"system_admin"}')"
if [[ "$status" -lt 400 ]]; then echo "Resident could update their own role" >&2; exit 1; fi

# Resident submits a report with an active category, owner and NEW status.
category_id="$(get_json "$rest/maintenance_categories?select=id&name=eq.Plumbing" "$a_token" | jq -er '.[0].id')"
new_report() {
  local title="$1"
  local payload
  payload="$(jq -nc --arg owner "$a" --argjson category "$category_id" --arg title "$title" \
    '{resident_id:$owner,category_id:$category,title:$title,description:"Sample issue for isolated integration test",location:"Room 101",status:"new"}')"
  post_json "$rest/maintenance_reports?select=id,status,resident_id" "$a_token" "$payload" | jq -er '.[0].id'
}
id1="$(new_report 'Actual Supabase valid report')"
id2="$(new_report 'Actual Supabase duplicate report')"
id3="$(new_report 'Actual Supabase inappropriate report')"

# Store an original 1x1 PNG under the private report-photos bucket.
# Storage RLS must allow the owner but reject other residents.
photo_path="$a/$id1/one-pixel.png"
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO2l9mYAAAAASUVORK5CYII=' \
  | base64 --decode > "$workdir/pixel.png"
status="$(curl -sS --max-time 20 -o "$workdir/storage_response" -w '%{http_code}' \
  -X POST "$storage/object/report-photos/$photo_path" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $a_token" \
  -H 'Content-Type: image/png' --data-binary "@$workdir/pixel.png")"
if [[ "$status" != "200" && "$status" != "201" ]]; then
  echo "Resident photo upload failed (HTTP $status)" >&2
  cat "$workdir/storage_response" >&2; exit 1
fi
photo_meta="$(jq -nc --argjson id "$id1" --arg uid "$a" --arg path "$photo_path" \
  '{report_id:$id,uploaded_by:$uid,storage_path:$path}')"
post_json "$rest/report_attachments?select=id,report_id" "$a_token" "$photo_meta" \
  | jq -e --argjson id "$id1" '.[0].report_id==$id' >/dev/null

# Moderator can read the private report photo by its correct report ownership.
curl -fsS --max-time 20 "$storage/object/report-photos/$photo_path" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $moderator_token" -o "$workdir/moderator_photo.png"
test -s "$workdir/moderator_photo.png"

# A different Resident cannot see private Storage data OR attachment metadata.
status="$(status_code GET "$storage/object/report-photos/$photo_path" "$b_token")"
if [[ "$status" -lt 400 ]]; then echo "Foreign Resident accessed private photo" >&2; exit 1; fi
get_json "$rest/report_attachments?select=id&report_id=eq.$id1" "$b_token" \
  | jq -e 'length==0' >/dev/null

# Other residents must not see this user's reports.
hidden="$(get_json "$rest/maintenance_reports?select=id&id=eq.$id1" "$b_token")"
echo "$hidden" | jq -e 'length==0' >/dev/null

# Actual authenticated REST RPC: unauthorized resident must not review.
payload="$(jq -nc --argjson id "$id2" '{p_report_id:$id,p_outcome:"duplicate",p_reason:"Already reported"}')"
status="$(status_code POST "$rest/rpc/review_maintenance_report" "$b_token" "$payload")"
if [[ "$status" -lt 400 ]]; then echo "Resident was allowed to review reports" >&2; exit 1; fi

# Moderator records a duplicate, admin records inappropriate.
post_json "$rest/rpc/review_maintenance_report" "$moderator_token" "$payload" | jq -e '. == true' >/dev/null
payload3="$(jq -nc --argjson id "$id3" '{p_report_id:$id,p_outcome:"inappropriate",p_reason:"Invalid content"}')"
post_json "$rest/rpc/review_maintenance_report" "$admin_token" "$payload3" | jq -e '. == true' >/dev/null

# Staff must be unable to claim a rejected report.
payload2="$(jq -nc --argjson id "$id2" '{p_report_id:$id}')"
status="$(status_code POST "$rest/rpc/claim_maintenance_report" "$staff_token" "$payload2")"
if [[ "$status" -lt 400 ]]; then echo "Staff claimed a rejected report" >&2; exit 1; fi

# Valid report still follows the original claim -> in_progress -> resolve flow.
payload1="$(jq -nc --argjson id "$id1" '{p_report_id:$id}')"
post_json "$rest/rpc/claim_maintenance_report" "$staff_token" "$payload1" | jq -e '. == true' >/dev/null

# Assigned Staff gains access to this report photo without elevated API keys.
curl -fsS --max-time 20 "$storage/object/report-photos/$photo_path" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $staff_token" -o "$workdir/staff_photo.png"
test -s "$workdir/staff_photo.png"

post_json "$rest/rpc/resolve_maintenance_report" "$staff_token" "$payload1" | jq -e '. == true' >/dev/null
get_json "$rest/maintenance_reports?select=status&id=eq.$id1" "$a_token" | jq -e '.[0].status=="resolved"' >/dev/null

# Negative backend validation: whitespace title must be rejected via API.
bad="$(jq -nc --arg owner "$a" --argjson category "$category_id" \
  '{resident_id:$owner,category_id:$category,title:"   ",description:"Invalid",location:"Room 101",status:"new"}')"
status="$(status_code POST "$rest/maintenance_reports" "$a_token" "$bad")"
if [[ "$status" -lt 400 ]]; then echo "Blank title was accepted" >&2; exit 1; fi

# An ordinary authenticated staff account sees zero private review rows.
get_json "$rest/report_reviews?select=report_id" "$staff_token" | jq -e 'length==0' >/dev/null

echo "PASS: Real local Supabase Auth, profile RBAC, owner RLS, private Storage, moderation, claim/resolve and input validation."
