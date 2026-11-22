# FixMate – SmartDormApp | Final Lecturer Handoff (current state)

**Date:** 22 November 2026  
**Course/project:** Kauno Kolegija, Software Systems Engineering, Internal Internship  
**Team:** Three students, nine-week Agile/Scrum plan, three sprints  
**Product:** Connected Flutter Android and Flutter Web dormitory maintenance reporting system  
**Integration PR:** [#46](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/46), still **open** for lecturer/team review  
**Live web:** https://ahmedfak105.github.io/PSe-4-FixMate-SmartDormApp/

This is the **current handoff**, superseding older internal presentation notes
which describe the original hosted six-table schema as still unchanged.

## 1. Product and stakeholder value

FixMate converts dormitory maintenance requests into structured, traceable
records. Residents create reports with category, description, location and
optional photo, then follow status changes and receive in-app notifications.
Maintenance Staff can claim eligible reports, write notes and resolve work.
Moderators can mark new reports valid, duplicate or inappropriate; a rejected
report is blocked from normal staff assignment. System Administrators can
monitor reports, assign work, edit categories and manage roles with an audit
trail. The same connected Supabase backend serves Web and Android.

## 2. Architecture and data

- **Clients:** Flutter Android, responsive Flutter Web role-specific pages,
  English/Lithuanian interface strings.
- **Identity:** Supabase Auth; `auth.users` is managed by Supabase.
- **Database:** Supabase PostgreSQL 17, **11** application tables in
  `public`, all with RLS. Core six:
  `profiles`, `maintenance_categories`, `maintenance_reports`,
  `report_attachments`, `report_notes`,
  `report_status_history`. Added five:
  `report_reviews`, `user_role_audit`, `report_notifications`,
  `push_device_tokens`, `push_delivery_outbox`.
- **Storage:** private `report-photos` bucket and private 2-MiB
  `profile-avatars` bucket.
- **Business logic:** ownership RLS, column-level grants and PostgreSQL
  RPCs for protected role/category changes, moderation and report workflow.
- **Push boundary:** Android Firebase client, DB outbox and deployed
  `send-report-push` Edge Function **v1 ACTIVE**. Actual background
  delivery still needs private Firebase credentials, invocation and
  real-phone confirmation.

See [current hosted 11-table ERD](FIXMATE_HOSTED_ERD.md).

## 3. Development and implementation

The three-student team organized 12 implementation tasks under the approved
Features/Epics in GitHub. Integration work combined Flutter Mobile, Flutter
Web, Supabase schema and tests in one review branch. Nine additive SQL
migrations were applied to the **existing live academic test project**
without replaying the original baseline or deleting data deliberately;
the original six accounts and six reports remained in post-deployment checks.
The owner explicitly accepted possible loss of disposable academic test data,
so no verified private backup or restore is claimed.

**Important for future maintainers:** hosted Supabase applied new migration
version stamps `20261122162335` through `20261122162452`, whereas the
committed source migration files have older timestamps. Read the
[hosted rollout log](HOSTED_RUNTIME_ROLLOUT_2026-11-22.md)
before any future `supabase db push`; do not blindly replay migrations.

## 4. Verification — evidence type matters

| Evidence source | What was checked | Result |
| --- | --- | --- |
| GitHub Actions | Flutter analysis/tests, connected Android APK build, Web build, Chrome E2E, SQL smoke and FCM guard suite | **Passed** on earlier integrated candidate; latest doc-only commits may have fresh concurrent CI |
| Hosted Supabase inspect | 11 application tables, all with RLS; moderator/admin RPCs; private avatars; queue/notifications | **Verified** |
| Hosted transaction-only SQL tests | Non-admin permission denial; Admin role/category writes; Moderator duplicate rejection + block staff action; notification trigger | **Passed**, test changes rolled back |
| Project-owner manual acceptance | User reports connected Web and Android functionality including roles, avatar and in-app notifications | **Reported successful**; not independently captured video |
| Firebase FCM | Edge function uploaded, ACTIVE v1, secret-header guard source | **Deployed but not delivered**; private credentials, trigger/scheduler and real Android background notification still **pending** |

These are different evidence levels. Do not call a successful CI build a real
phone delivery test. The project is a working academic MVP, not a fully signed
off public production launch.

### Reproducible GitHub Actions evidence

- [Connected Android APK on integrated revision `8b309128`](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/45040526078) — **SUCCESS**; compiled connected debug APK artifact uploaded.
- [Real Flutter Web Chrome E2E](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/45040530317) — **SUCCESS** on the same integration revision.
- [Integrated Android/Web/Flutter/isolated DB release candidate](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/45040530260) — **SUCCESS**.
- [GitHub Pages Web deploy](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/45040526030) — **SUCCESS**.
- Hosted SQL/RLS/role/notification status is supported by fresh live checks described in [rollout log](HOSTED_RUNTIME_ROLLOUT_2026-11-22.md) and [release gate #47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47). GitHub CI does **not** prove FCM OS delivery.

### Final hosted FCM bridge status (updated 22 Nov 2026)

- The deployed `send-report-push` Edge sender **ACTIVE v1** now has a
  **Vault-gated** database trigger on outbox inserts plus an **active 5-minute
  retry cron**. The `pg_net` extension was reinstalled under the
  `extensions` namespace after a Security Advisor warning.
- Actual hosted migrations `20261122170759`
  (`fixmate_push_vault_bridge_live`) and `20261122171136`
  (`fixmate_pgnet_extension_harden_live`) were applied and checked.
- **No Firebase service-account secret or matching webhook secret is set
  through these tools; the system fails closed and produces no FCM HTTP
  sends.** Android locked-screen delivery remains unverified. Source of
  truth: [activation guide](FCM_SERVER_FINAL_ACTIVATION_2026-11-22.md).
- Existing experimental report count can change as users test; the six
  reports mentioned in the nine-migration rollout were a point-in-time
  count, not a permanent production number.

## 5. Demonstration (5 minutes)

1. **Resident:** Sign in with a dedicated test Resident, edit profile/avatar,
   create a report and show its details.
2. **Moderator:** Log in with a dedicated test Moderator, review a new,
   unassigned report and discuss valid vs rejected outcomes.
3. **Staff:** Show available jobs, claim an eligible report and update to
   `in_progress` or `resolved`.
4. **Admin:** Show dashboard counts, People role management and Categories
   management. Explain why a resident cannot elevate their own role.
5. **Resident:** Return to My Reports and show the new status plus the
   stored in-app notification. If Firebase server secrets are not yet
   configured, explicitly state that OS background push is still pending.

Never show test users' passwords, private Storage URLs, Supabase secret API
keys or Firebase service-account contents.

## 6. Database SQL examples for the lecturer (read-only)

```sql
-- Tables and RLS flags in the current project
select c.relname, c.relrowsecurity
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r'
order by c.relname;

-- Status distribution without exposing residents' names
select status, count(*) as reports
from public.maintenance_reports
group by status order by status;

-- Confirm private buckets without revealing photo paths
select id, public, file_size_limit
from storage.buckets
where id in ('report-photos', 'profile-avatars')
order by id;

-- Audit table inventory (no personal data)
select count(*) as role_change_audit_rows
from public.user_role_audit;

-- Notification totals only (no user details)
select count(*) as resident_status_notifications
from public.report_notifications;
```

## 7. Critical pending acceptance

The deployed FCM Edge sender is deliberately protected by an independent
strong `x-fixmate-push-secret` header and should fail closed without
configuration. See the [private operator activation checklist](FCM_SERVER_FINAL_ACTIVATION_2026-11-22.md).
An authorized operator needs to supply private Firebase service-account
credentials **directly in Supabase secrets**, configure the DB webhook and
trusted retry schedule, then confirm actual locked-screen Android delivery
and cross-account isolation. The teacher/team must sign off the final scope.
Until then, [F05.2 #24](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/24)
and [Release Gate #47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47)
remain open; do not merge [PR #46](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/46)
as if the release gate were complete.

## 8. Lecturer resources

- [Integrated review PR #46](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/46)
- [Current hosted SQL rollout](HOSTED_RUNTIME_ROLLOUT_2026-11-22.md)
- [Current database ERD](erd/FIXMATE_HOSTED_11_TABLES.mmd)
- [Live Web](https://ahmedfak105.github.io/PSe-4-FixMate-SmartDormApp/)
- [FCM remaining setup](FCM_SERVER_FINAL_ACTIVATION_2026-11-22.md)
- [Release checklist #47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47)
