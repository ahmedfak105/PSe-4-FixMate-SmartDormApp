# FixMate — Trusted Staff / Moderator / Admin Provisioning

**Covers:** TASK #35 (Supabase authentication profiles and role-based access), TASK #38 (role-aware web entry), TASK #39 (Moderator review testing).  
**Date:** 22 Nov 2026  
**Status:** Documentation of the verified existing model, **not** an implemented admin account-creation feature or a passed role E2E test.

## 1. Current backend facts (verified by read-only Supabase inspection)

- `public.profiles.role` accepts exactly `resident`, `maintenance_staff`, `moderator`, `system_admin`.
- `auth.users` has an `on_auth_user_created` trigger calling `private.handle_new_user()`; this code always inserts a new profile with **`role='resident'`**.
- An `authenticated` client has **no direct INSERT on profiles** and **no direct UPDATE on `profiles.role`**.
- A plain user signup **cannot assign a privileged role** by including `role` in user metadata; authorization is stored in `public.profiles`, not editable `auth.user_metadata`.
- Snapshot: 3 residents, 2 maintenance_staff, 1 system_admin, **0 moderators**; all 6 Auth users have a profile.
- Existing browser dashboard requires `system_admin` role. Staff and Moderator each have their own code-level role guard; **security enforcement must also be tested via real API/RLS**.

## 2. Approved trusted account provisioning procedure (staging first)

This is a **manual operator-controlled** procedure, not a user-facing registration workflow:

1. In a staging Supabase project, an authorized operator opens **Authentication → Users** and creates/invites a **test** email account. Use a test inbox you control and a unique password; never share passwords or session tokens in GitHub issues or screenshots.
2. Confirm an entry exists in `auth.users` and that the Auth trigger created its matching `public.profiles` row with **`role='resident'`**.
3. Using the **privileged Supabase SQL Editor session** (not a browser publishable/anon key), an authorized operator may assign one of the agreed elevated roles to this **specific verified account ID**. This step is deliberately kept as a commented example below and must **not** be run against real-user IDs by copy/paste.
4. Refresh the new test user's session, verify role routing in the proper Flutter/Web client, and confirm disallowed roles cannot call RPCs or access other users' records.
5. Record the testing evidence (role, account identifier redacted, action, expected vs actual result) without recording credentials.

### Operator SQL examples (commented; execute only after review)

```sql
-- STAGING ONLY. The operator must verify the UUID via Auth dashboard first.
-- SELECT id, role FROM public.profiles WHERE id = '<TEST_AUTH_UUID>'::uuid;
--
-- UPDATE public.profiles
-- SET role = 'moderator'
-- WHERE id = '<VERIFIED_TEST_AUTH_UUID>'::uuid
--   AND role = 'resident'
-- RETURNING id, role;
--
-- Other permitted elevated roles: maintenance_staff, system_admin.
-- NEVER expose this privileged UPDATE via a client-side key, open policy,
-- public endpoint, or ordinary resident registration form.
```

No automated elevation endpoint is assumed to exist. Administrative user/role editing **from the Admin Dashboard** remains outside the currently implemented scope and is not falsely claimed as working.

## 3. Required tests before marking TASK #35 Done

| Test | Expected |
|---|---|
| Sign up with ordinary email/password | `auth.users` and matching Resident profile exist |
| Send signup metadata `role='system_admin'` | Profile remains Resident |
| Authenticated Resident attempts `profiles.role` UPDATE | Denied by DB grants/RLS |
| Resident tries `assign_maintenance_report` or `claim_maintenance_report` | Rejected by protected backend function |
| Staff claims own eligible new report | Succeeds once and creates history |
| Staff attempts to resolve another staff member's report | Denied / no mutation |
| Moderator reviews via `review_maintenance_report` after staging migration | Succeeds only for eligible report; result persisted |
| Staff/Resident attempt review RPC | Rejected |
| System Admin opens admin dashboard | Allowed; other roles denied |
| Resident tries another resident's report / private image | RLS/Storage deny |
| New profile metadata includes injected privileged keys | Ignored for authorization |
| Confirm password recovery & status | Separate product feature, not assumed done |

**Do not rely solely on SQL Editor tests** to prove `authenticated` role permissions. Use the app or API with each role's actual access token on staging.

## 4. Safe Moderator demo setup

Create a **new staging test user** and elevate only that verified test profile to `moderator` through the privileged operator process above. Never promote a real Resident account merely to demo Moderator. After installing and verifying the proposed report-review migration, sign in to the web interface and demonstrate valid/duplicate/inappropriate review outcomes and restricted photo access.

## 5. Security restrictions

- No service-role key, database password, or secret key may appear in Flutter, HTML, JS or a GitHub repository.
- Use normal publishable/anon key in client apps with Supabase Auth and backend RLS.
- Restrict trusted role provisioning to operators; record any changes and scope them to verified test identities.
- If providing self-service role administration later, it must use a separate authenticated and authorized server-side operation, not an exposed `UPDATE profiles.role` grant.
- Authentication `user_metadata` is user-editable and must not be a source of permissions.
- A verified staff/admin profile count is not evidence all role-negative tests passed.

**Current result:** This documentation satisfies the *procedure documentation* subtask of TASK #35, but does not close TASK #35's end-to-end sign-up and negative-permission acceptance checks.
