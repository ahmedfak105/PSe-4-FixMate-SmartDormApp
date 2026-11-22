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

# Invalid email/password must be rejected by GoTrue Auth API.
bad_login="$(jq -nc --arg email "$a_email" '{email:$email,password:"not-the-correct-password"}')"
bad_status="$(curl -sS --max-time 20 -o "$workdir/invalid_login" -w '%{http_code}' \
  -X POST "$auth/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" -H 'Content-Type: application/json' \
  --data "$bad_login")"
if [[ "$bad_status" -lt 400 ]]; then echo "Bad credentials were accepted" >&2; exit 1; fi

# Sign out a test account and verify the Auth endpoint accepts its session.
logout_status="$(curl -sS --max-time 20 -o "$workdir/logout_response" -w '%{http_code}' \
  -X POST "$auth/logout" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $b_token")"
if [[ "$logout_status" -lt 200 || "$logout_status" -ge 300 ]]; then
  echo "Supabase logout failed ($logout_status)" >&2; exit 1
fi
# Log in again for the cross-resident RLS tests below.
b_token="$(login "$b_email")"


# Auth-to-profile trigger always creates Resident from untrusted signup metadata.
a_profile="$(get_json "$rest/profiles?select=id,role&id=eq.$a" "$a_token")"
echo "$a_profile" | jq -e --arg id "$a" 'length == 1 and .[0].id==$id and .[0].role=="resident"' >/dev/null

# A Resident must not elevate profiles.role through the actual REST API.
status="$(curl -sS --max-time 20 -o "$workdir/error_response" -w '%{http_code}' \
  -X PATCH "$rest/profiles?id=eq.$a" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $a_token" \
  -H 'Content-Type: application/json' --data '{"role":"system_admin"}')"
if [[ "$status" -lt 400 ]]; then echo "Resident could update their own role" >&2; exit 1; fi

# Self-service profile editing and private avatars (isolated local migrations).
# The owner can update only editable contact columns, never role/id.
profile_update='{"full_name":"Updated Resident A","building":"Building C","room_number":"204"}'
updated_status="$(curl -sS --max-time 20 -o "$workdir/profile_update" -w '%{http_code}' \
  -X PATCH "$rest/profiles?id=eq.$a&select=id,full_name,building,room_number,role" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $a_token" \
  -H 'Content-Type: application/json' -H 'Prefer: return=representation' \
  --data "$profile_update")"
if [[ "$updated_status" != "200" ]]; then
  echo "Own profile edit failed (HTTP $updated_status)" >&2
  cat "$workdir/profile_update" >&2; exit 1
fi
jq -e --arg uid "$a" 'length == 1 and .[0].id==$uid and
  .[0].full_name=="Updated Resident A" and .[0].building=="Building C" and
  .[0].room_number=="204" and .[0].role=="resident"' "$workdir/profile_update" >/dev/null

foreign_status="$(curl -sS --max-time 20 -o "$workdir/foreign_update" -w '%{http_code}' \
  -X PATCH "$rest/profiles?id=eq.$a&select=id" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $b_token" \
  -H 'Content-Type: application/json' -H 'Prefer: return=representation' \
  --data '{"full_name":"Unauthorized rename"}')"
if [[ "$foreign_status" == "200" ]]; then
  jq -e 'length == 0' "$workdir/foreign_update" >/dev/null ||
    { echo "Foreign profile modification was allowed" >&2; exit 1; }
elif [[ ! "$foreign_status" =~ ^4[0-9][0-9]$ ]]; then
  echo "Unexpected foreign profile PATCH status: $foreign_status" >&2; exit 1
fi

# Authenticated users never gain column privilege to modify role, including
# when trying to mix it with an otherwise valid profile update.
mixed_status="$(curl -sS --max-time 20 -o "$workdir/role_mixed" -w '%{http_code}' \
  -X PATCH "$rest/profiles?id=eq.$a" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $a_token" \
  -H 'Content-Type: application/json' --data '{"full_name":"Changed","role":"system_admin"}')"
if [[ ! "$mixed_status" =~ ^4[0-9][0-9]$ ]]; then
  echo "Profile role changed through mixed PATCH" >&2; exit 1
fi

avatar_path="$a/ci-avatar.png"
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO2l9mYAAAAASUVORK5CYII=' \
  | base64 --decode > "$workdir/avatar.png"
avatar_upload="$(curl -sS --max-time 20 -o "$workdir/avatar_upload" -w '%{http_code}' \
  -X POST "$storage/object/profile-avatars/$avatar_path" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $a_token" \
  -H 'Content-Type: image/png' --data-binary "@$workdir/avatar.png")"
if [[ "$avatar_upload" != "200" && "$avatar_upload" != "201" ]]; then
  echo "Own avatar upload rejected: HTTP $avatar_upload" >&2
  cat "$workdir/avatar_upload" >&2; exit 1
fi
avatar_patch="$(curl -sS --max-time 20 -o "$workdir/avatar_patch" -w '%{http_code}' \
  -X PATCH "$rest/profiles?id=eq.$a&select=id,avatar_path" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $a_token" \
  -H 'Content-Type: application/json' -H 'Prefer: return=representation' \
  --data "$(jq -nc --arg path "$avatar_path" '{avatar_path:$path}')")"
if [[ "$avatar_patch" != "200" ]]; then
  echo "Own avatar database update rejected: HTTP $avatar_patch" >&2
  cat "$workdir/avatar_patch" >&2; exit 1
fi
jq -e --arg path "$avatar_path" 'length == 1 and .[0].avatar_path==$path' \
  "$workdir/avatar_patch" >/dev/null

curl -fsS --max-time 20 "$storage/object/profile-avatars/$avatar_path" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $a_token" \
  -o "$workdir/downloaded-avatar.png"
test -s "$workdir/downloaded-avatar.png"
avatar_foreign="$(status_code GET "$storage/object/profile-avatars/$avatar_path" "$b_token")"
if [[ ! "$avatar_foreign" =~ ^4[0-9][0-9]$ ]]; then
  echo "Foreign account read another user's private avatar" >&2; exit 1
fi
avatar_foreign_upload="$(curl -sS --max-time 20 -o "$workdir/avatar_foreign_upload" -w '%{http_code}' \
  -X POST "$storage/object/profile-avatars/$avatar_path" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $b_token" \
  -H 'Content-Type: image/png' --data-binary "@$workdir/avatar.png")"
if [[ ! "$avatar_foreign_upload" =~ ^4[0-9][0-9]$ ]]; then
  echo "Foreign account uploaded to another user's avatar path" >&2; exit 1
fi
echo 'PASS: own profile edits, immutable role, and private avatar ownership'

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

# Task #36 API negative matrix: verify HTTP 4xx, not merely any failure.
# These queries run on disposable Supabase only; the new validation SQL is
# still proposed and has NOT been applied to active remote FixMate.
expect_rejected_report() {
  local label="$1" actor_token="$2" payload="$3"
  local http
  http="$(status_code POST "$rest/maintenance_reports" "$actor_token" "$payload")"
  if [[ ! "$http" =~ ^4[0-9][0-9]$ ]]; then
    echo "Unexpected API response for $label: HTTP $http (expected a 4xx)" >&2
    cat "$workdir/error_response" >&2 || true
    exit 1
  fi
}
valid_payload="$(jq -nc --arg owner "$a" --argjson category "$category_id" \
  '{resident_id:$owner,category_id:$category,title:"Valid report title",
    description:"Clear description",location:"Room 101",status:"new"}')"
expect_rejected_report 'blank title' "$a_token" \
  "$(echo "$valid_payload" | jq -c '.title="   "')"
expect_rejected_report 'blank description' "$a_token" \
  "$(echo "$valid_payload" | jq -c '.description="   "')"
expect_rejected_report 'blank location' "$a_token" \
  "$(echo "$valid_payload" | jq -c '.location="   "')"
long_title="$(printf 'T%.0s' {1..121})"
expect_rejected_report 'title over 120 chars' "$a_token" \
  "$(echo "$valid_payload" | jq -c --arg title "$long_title" '.title=$title')"
expect_rejected_report 'invalid initial status' "$a_token" \
  "$(echo "$valid_payload" | jq -c '.status="in_progress"')"
expect_rejected_report 'foreign resident report owner' "$a_token" \
  "$(echo "$valid_payload" | jq -c --arg owner "$b" '.resident_id=$owner')"
expect_rejected_report 'staff creating a resident report' "$staff_token" "$valid_payload"
expect_rejected_report 'unknown maintenance category' "$a_token" \
  "$(echo "$valid_payload" | jq -c '.category_id=999999999')"
inactive_category="$(psql -X -qAt -v ON_ERROR_STOP=1 -c \
  "INSERT INTO public.maintenance_categories(name,is_active)
   VALUES ('Inactive API integration category',false) RETURNING id;")"
if [[ ! "$inactive_category" =~ ^[0-9]+$ ]]; then
  echo 'Could not create isolated inactive test category' >&2; exit 1
fi
expect_rejected_report 'inactive maintenance category' "$a_token" \
  "$(echo "$valid_payload" | jq -c --argjson category "$inactive_category" '.category_id=$category')"
echo 'PASS: nine negative report-input/role cases returned HTTP 4xx'

# An ordinary authenticated staff account sees zero private review rows.
get_json "$rest/report_reviews?select=report_id" "$staff_token" | jq -e 'length==0' >/dev/null

echo "PASS: Real local Supabase Auth, profile RBAC, owner RLS, private Storage, moderation, claim/resolve and input validation."
