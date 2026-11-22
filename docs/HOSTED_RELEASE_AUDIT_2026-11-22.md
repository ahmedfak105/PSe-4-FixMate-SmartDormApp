# FixMate — verified hosted release audit (22 November 2026)

**Project:** `epsvagztisdovixlqehi` (existing hosted Supabase, not disposable CLI).
**Method:** read-only Supabase table inventory, catalog/privilege SQL, Storage bucket inventory, migration history, security/performance advisors, and exact GitHub Actions statuses. **No hosted data, grants, secrets, files, Auth accounts, migrations or billing were changed.**

## Confirmed release assets and checks

- **Connected-only Flutter:** [PR #49](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/49) was merged into integration as `7f035cd1`. No runtime Demo/offline sample reports, demo app banner or unconfigured fallback. Isolated fake data remain under `mobile/test/` for automated tests only.
- **FCM sender security:** [PR #48](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/48) was merged into integration as `17a632d7`. It adds typed FCM UNREGISTERED handling, webhook-secret tests and current `sb_secret_` support. **It does not activate push delivery on the server.**
- **At `7f035cd1`:** [integrated Android + Web + Flutter checks](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/45037538117) **SUCCESS**, [real Chrome E2E](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/45037538063) **SUCCESS**, [isolated database smoke](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/45037538284) **SUCCESS**.
- **Web:** [GitHub Pages build + deploy](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/45037533703) **SUCCESS**, published location: https://ahmedfak105.github.io/PSe-4-FixMate-SmartDormApp/ . Still needs independent hosted browser sign-in with each authorized real role.
- **Android:** [Connected Android APK workflow](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/45037533789) **SUCCESS**. This is an unsigned-for-store **debug APK**, not a store/release distribution. Physical-device install, role sign-in and background push tests still outstanding.

## Actual hosted database inventory (read-only)

| Property | Observed result |
|---|---|
| Public application tables | **6**, each with RLS enabled |
| Profiles / reports | **6 profiles**, **5 reports** |
| Current role counts | **3 Resident**, **2 Maintenance Staff**, **1 System Admin**, **0 Moderator** |
| Self-edit privileges | `full_name`, `building`, `room_number`: UPDATE granted; `role`: UPDATE **not** granted to authenticated |
| Existing private report-photo bucket | `report-photos` (private, 5 MiB limit, JPEG/PNG/WebP) |
| `profiles.avatar_path` column | **Absent** |
| Private `profile-avatars` Storage bucket | **Absent** |
| `report_reviews` / moderator review RPC | **Absent** |
| Category management RPC | **Absent** |
| Audited user-role management / `user_role_audit` | **Absent** |
| In-app `report_notifications` | **Absent** |
| `push_device_tokens`, `push_delivery_outbox`, push claim RPC | **Absent** |
| Existing live `assign_maintenance_report`, `claim_maintenance_report`, `resolve_maintenance_report` functions | Present as invoker functions (not `SECURITY DEFINER`) |
| Supabase migration history | **Empty**, despite populated manually created application tables |
| Security advisor | One `auth_leaked_password_protection` warning (check entitlement before any plan change) |
| Performance advisor | Nine missing FK-covering indexes; three overlapping permissive policies |

**Re-runnable read-only verifier:** [`docs/sql/FIXMATE_HOSTED_RELEASE_AUDIT_READ_ONLY.sql`](sql/FIXMATE_HOSTED_RELEASE_AUDIT_READ_ONLY.sql). The queries were executed against the existing hosted project without mutation; only aggregate counts, policy definitions and function signatures are requested.

**Interpretation:** Resident and Staff flows are connected to real backend infrastructure. Profile name/building/room access is configured, but must still pass authorized app-session save tests. Moderator review, profile avatars, category writes, admin role writes, in-app notifications and FCM delivery are **not yet live**. A compiled button or a passing *local* RLS test cannot certify a missing hosted backend feature.

## Deployment gate: mandatory order (do not skip)

1. **Approve scope and downtime:** obtain team/lecturer review of [release gate #47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47). Do not merge the broader [integration PR #46](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/46) into `main` as a proxy for approving hosted SQL.
2. **Take a verified recoverable backup** of the populated database **including Auth** and a separate copy of private Storage objects. Store both securely outside GitHub/chat. Conduct a restoration rehearsal in an isolated environment and record its success. Supabase [official backup guide](https://supabase.com/docs/guides/platform/backups) recommends periodic manual CLI dumps for Free projects; do **not** assume this project's plan provides an accessible daily backup.
3. **Reconcile drift and history:** inventory the actual live schema and `supabase_migrations.schema_migrations` carefully. Do not run `supabase db reset`, import/replay `20261121222817_fixmate_baseline.sql`, or blindly run all versioned files against the populated original tables. Use a reviewed migration-history reconciliation plan.
4. **Review & test only the additive changes** for the existing schema in a disposable staging clone/instance. The ordered source candidates (not deployment approval) are:
   - `20261121223150_fixmate_fk_indexes.sql` — missing FK indexes.
   - `20261122000339_fixmate_report_validation.sql` — input constraints after checking existing rows.
   - `20261122000340_fixmate_moderator_review.sql` — review table/RPC and moderator access.
   - `20261122133000_profile_self_service_avatars.sql` — private avatar bucket, owner-only Storage RLS and safe profile field grants.
   - `20261122150000_category_management.sql` — controlled admin category RPC.
   - `20261122193000_admin_role_management.sql` — audited role changes.
   - `20261122194500_report_notifications.sql` — owner-only status inbox.
   - `20261122210500_fcm_device_tokens.sql` — owner-only Android registration.
   - `20261122234000_fcm_push_delivery_outbox.sql` — backend queue/claim/revocation.
   Each file requires independent object-name/trigger/grant review against the hosted schema. **DO NOT copy the local seed/baseline into hosted.**
5. **Stage authorization tests:** Resident can read/modify only own reports/profile/photos; Staff can claim/update only authorized work; Moderator reviews a report once; Admin controls categories and roles without client `service_role` keys; another user's device token/avatar cannot be retrieved. One Moderator **must be securely provisioned by an authorized operator** for live acceptance; none currently exists.
6. **Enable Firebase sender only after schema/secret signoff:** configure the [FCM outbox service](F05_2_FREE_PUSH_REQUIREMENTS.md) using restricted service-account credentials stored in Supabase Edge Function secrets, an independent webhook secret, and an approved bounded retry scheduler. Verify new Supabase `sb_secret_` authorization for `claim_fixmate_push_jobs` in staging (a pure helper test is not enough). Test delivery on a **real** Android phone, sign-out revocation and recipient isolation. Never assume the reported Google Cloud $300 credit's remaining balance/expiry.
7. **Publish and verify:** rebuild connected Android + Web, capture checks on the *exact* deployed source SHA, open the actual Pages URL on phone/desktop, test email login/recovery and all four roles, check Supabase advisors again, and record backup/restore evidence. Only then close #24 and #47 or seek final `main` merge.

## Remaining release-owner evidence

- Secure, verified database **and Storage backup + restore rehearsal**.
- Signoff for changed hosted SQL and schema/migration-history reconciliation.
- Live Moderator role account and four-role cross-account acceptance.
- Avatar, admin role/category and in-app status-notification hosted tests.
- Firebase Edge Function secrets, service-role RPC authorization and real background push.
- Actual phone APK install, screenshots of tests and signed release decision.

**Release status:** **Connected Android/Web build and GitHub Pages: yes. Full hosted multi-role functionality and Firebase push: not yet.** No spending or unauthorized hosted modification is permitted solely to change that status.
