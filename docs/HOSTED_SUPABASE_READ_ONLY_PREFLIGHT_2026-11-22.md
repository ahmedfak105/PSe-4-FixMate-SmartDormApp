# FixMate — Hosted Supabase read-only release preflight (2026-11-22)

**Scope:** Existing hosted project `epsvagztisdovixlqehi` only. Evidence gathered with read-only schema inspection, SQL SELECT, migration listing, and Supabase advisors. **No schema, Auth, Storage, or application data changes were made.**

## Verified live state

| Check | Result |
|---|---|
| Hosted Supabase project | ACTIVE_HEALTHY (PostgreSQL 17) |
| Public application tables | 6; all have RLS enabled |
| Rows in `maintenance_reports` | 5 |
| Existing reports failing proposed required-field/title-length checks | 0 |
| Reports referencing inactive/missing categories | 0 |
| Public table RLS policies | 13 |
| Auth profile creation trigger `on_auth_user_created` | Present (1) |
| `report_reviews` | Not present |
| `review_maintenance_report` RPC | Not present |
| `fixmate_block_rejected_report_work` trigger | Not present |
| Supabase migration history | Empty |
| Supabase development branches | None |

**Interpretation:** Current populated hosted database still uses the original six-table schema. The proposed report-validation and Moderator review extensions have **not** been rolled out. Existing rows passed the *specific compatibility checks above*, not a comprehensive production qualification.

## Security and performance advisor findings (2026-11-22)

- **Security:** Leaked-password protection is disabled (WARN). See [Supabase password security](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). This is an Auth dashboard setting; review before external deployment.
- **Performance:** 9 foreign keys lack covering indexes (INFO). See [Supabase advisor: unindexed foreign keys](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys). The fresh-local migrations include these indexes; the hosted database has not yet received them.
- **Performance:** 3 overlapping permissive SELECT-policy cases (WARN), on `maintenance_reports`, `profiles`, and `report_attachments`. See [Supabase advisor: multiple permissive policies](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies). Review actual authorization semantics with negative-role tests before consolidating anything.

These advisories do **not** by themselves establish a demonstrated data leak; and local CI success does **not** establish hosted authorization correctness.

## Controlled next steps

1. Reviewer signs off [integrated draft PR #46](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/46) after latest integrated CI checks and scope review. Do not merge automatically.
2. Provision a **separate approved Supabase staging project**, with synthetic test accounts/data only; never reuse hosted credentials or export personal resident records into staging.
3. Back up and document restore procedure before any hosted changes. Compare the live baseline against [remote read-only preflight](sql/REMOTE_ADDITIVE_PREDEPLOY_READ_ONLY.sql) and [controlled rollout guide](CONTROLLED_SUPABASE_ROLLOUT_TASK36_TASK39.md).
4. Test the **additive** validation + review migrations against staging with Resident A/B, Staff, Moderator, Admin, REST/Storage negative tests, and simultaneous staff-claim race.
5. Verify no RLS regression, invalid moderator approvals, duplicate policies, or unauthorized access. Capture synthetic four-role lecturer demo evidence.
6. Schedule reviewed hosted deployment only after the above gates pass; **never** run fresh-project baseline migrations against this populated project.

## Precise acceptance status

**12/12 original implementation TASKs are closed based on local code/tests. Hosted release gate [#47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47) is still open.** This preflight adds evidence only and makes no claim of hosted deployment or lecturer final approval.
