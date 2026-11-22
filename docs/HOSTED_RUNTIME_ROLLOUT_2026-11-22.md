# FixMate — hosted Supabase incremental rollout (2026-11-22)

## What changed, and why

**The project owner explicitly accepted possible loss of the existing experimental accounts/reports and requested that backup work should not block completing FixMate.** Nine previously reviewed/additive SQL changes were therefore applied directly to the **existing** hosted Supabase project `epsvagztisdovixlqehi` in source-order. This is a documented exception to the earlier release-gate preference for verified recovery. **No backup or isolated restore was performed.** No intentional deletes/reset of accounts/reports were performed, and no paid resource was created.

**Do not re-run the fresh baseline** `20261121222817_fixmate_baseline.sql` or the categories seed `20261121222818_fixmate_categories_seed.sql`: the six baseline tables and eight categories existed before the rollout.

## Applied migrations — hosted migration history

All nine calls to Supabase's migration application facility returned success and are now recorded in the hosted migration history. These are the **actual remote versions**, not the earlier source-file timestamps:

| Hosted version | Recorded name | Source migration |
| --- | --- | --- |
| `20261122162335` | `fixmate_fk_indexes_live` | `20261121223150_fixmate_fk_indexes.sql` |
| `20261122162338` | `fixmate_report_validation_live` | `20261122000339_fixmate_report_validation.sql` |
| `20261122162359` | `fixmate_moderator_review_live` | `20261122000340_fixmate_moderator_review.sql` |
| `20261122162406` | `fixmate_profile_avatars_live` | `20261122133000_profile_self_service_avatars.sql` |
| `20261122162430` | `fixmate_category_management_live` | `20261122150000_category_management.sql` |
| `20261122162434` | `fixmate_admin_role_management_live` | `20261122193000_admin_role_management.sql` |
| `20261122162439` | `fixmate_report_notifications_live` | `20261122194500_report_notifications.sql` |
| `20261122162448` | `fixmate_fcm_device_tokens_live` | `20261122210500_fcm_device_tokens.sql` |
| `20261122162452` | `fixmate_fcm_push_delivery_outbox_live` | `20261122234000_fcm_push_delivery_outbox.sql` |

**Migration history warning:** the hosted database originally had six pre-existing tables but **zero** migration records. Live history now contains versions/names generated during the hosted operations, which do **not** match committed `supabase/migrations/` filenames. Before a future CLI `db push`, explicitly reconcile baseline plus these applied hosted versions; do **not** blindly push 11 source migration files or reset the hosted database. Future clean local development can continue to use the original source files in order.

## Read-only verification after rollout

- **11** application tables now exist in `public` (6 baseline + `report_reviews`, `user_role_audit`, `report_notifications`, `push_device_tokens`, `push_delivery_outbox`); **all 11 have RLS enabled**.
- **6** profiles and **6** maintenance reports remain (no data was intentionally wiped).
- **9** existing FK indexes installed; report validation has **3** constraints and active-category INSERT policy.
- `profiles.avatar_path` now exists. The `profile-avatars` bucket is **private**, has a **2 MiB** file limit, and owner-only read/upload policies. Authenticated users can update their avatar path but **cannot directly update their role**.
- The moderator `report_reviews` table, `review_maintenance_report` RPC and rejected-report assignment-blocking trigger exist. No Moderator test account was created (existing profiles contained 0 Moderators at prior audit).
- Admin role/category-management capability RPCs, audited role write RPC, private status notifications, device token registry and server-only FCM delivery outbox/claim RPC now exist.
- Anonymous/fictitious non-admin impersonation in rollback-only SQL tests confirmed **role/category management and moderation are rejected**. An existing system_admin identity passed role/category capability checks, in a rollback-only test, without changing records.
- Notification status-change trigger smoke test passed within an explicit `BEGIN ... ROLLBACK` transaction, generating exactly one notification for one simulated status update, then reverting the entire test.
- **Moderator live DB transaction smoke passed:** temporarily impersonated an actual Resident as Moderator inside `BEGIN...ROLLBACK`, inserted one disposable draft report, reviewed it `duplicate` as `authenticated`, confirmed Moderator SELECT policy and second-review rejection, then verified the rejected report's workflow trigger blocks `in_progress`. The transaction was **rolled back**, not committed. Post-test counts were still 6 profiles, 3 Residents, 0 Moderators, 6 reports, 0 QA reports, 0 persisted moderation reviews or notifications. This is a database-side test, not an app UI test.
- Supabase linter rechecked after deployment. Remaining security warnings include intentional authenticated `SECURITY DEFINER` capability/RPC endpoints with explicit role checks, an intentionally private outbox table with zero browser-facing RLS policies, and the Free-tier Auth leaked-password-protection warning (the latter is not upgraded automatically). Performance advisor noted four new FK indexes which are not yet optimized, unused new indexes and overlapping permissive SELECT policies. See the [official database linter](https://supabase.com/docs/guides/database/database-linter).

## Still NOT independently proven or deployed

1. Real user login tests with the refreshed web/Android app after the hosted migration for **avatar upload**, Admin role/category writes, Moderator acceptance/rejection, Resident notification inbox, device-token registration. CI tested staged SQL, but a real app session is still required for interactive acceptance.
2. **Firebase Cloud Messaging background push remains not live**. The server-only `send-report-push` Edge Function is prepared in source but was **not deployed**. A private Firebase service-account JSON, strong server webhook secret, and approved invocation configuration are not available in the connected tools, so no functional delivery test is possible. An outbox record does not mean a push was sent.
3. Release Gate #47 and integration-to-`main` PR #46 remain open; final lecturer/team acceptance, private-device push proof, and any remaining project scope checks are outstanding.

## Immediate user acceptance steps

1. Open published [FixMate Web](https://ahmedfak105.github.io/PSe-4-FixMate-SmartDormApp/) and **refresh**. As a Resident, edit profile (including an actual private image upload) and verify a new maintenance report works.
2. As system_admin, test Categories and People (assign `moderator` to a **dedicated testing user** through the audited Admin UI; do not alter someone else's real account). Login as that Moderator to review an available, new/unassigned report.
3. As Staff, update an assigned report from `new` to `in_progress` or `resolved`; return as Resident and inspect the newly created notification.
4. Physical Android foreground/background push remains a separate task requiring the trusted Firebase service-account secret configured through a private server channel and Edge Function deployment.

This log is a factual deployment/verification record, **not** a claim that every UI and phone push path has been accepted.
