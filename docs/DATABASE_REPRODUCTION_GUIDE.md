# FixMate — Rebuilding the Backend from a Clean Supabase Environment

**TASK #34 — Design Supabase database schema**, including the acceptance criterion **"Schema changes are documented and reproducible."**

## Current verified status (22 Nov 2026)

The existing active FixMate project has **6 public tables**, **20 constraints**, **8 application functions**, **13 public RLS policies**, **3 Storage RLS policies**, a private `report-photos` bucket, and an Auth-to-profile trigger. However **no migration history and no Supabase development branches** were returned by the project. The existing setup currently works but **has not yet been reproduced from scratch**.

This folder now contains the following staging-only working drafts:

| File | Purpose / execution status |
|---|---|
| [VERIFIED_BASELINE_RECONSTRUCTION_DRAFT.sql](sql/VERIFIED_BASELINE_RECONSTRUCTION_DRAFT.sql) | Catalog-derived reconstruction of the **existing** six-table system and backend grants/functions/RLS/Storage. **Not executed or validated** on a fresh instance |
| [VERIFIED_CATEGORY_SEED_DRAFT.sql](sql/VERIFIED_CATEGORY_SEED_DRAFT.sql) | Eight category names/statuses, no report or user data. **Not executed** |
| [BASELINE_READ_ONLY_VERIFICATION.sql](sql/BASELINE_READ_ONLY_VERIFICATION.sql) | Catalog, privileges, policy and bucket read-only checks to run **after staging setup** |
| [PROPOSED_FOREIGN_KEY_INDEXES.sql](sql/PROPOSED_FOREIGN_KEY_INDEXES.sql) | Nine suggested indexes for the current missing-index findings; **not part of the verified baseline**, not executed |
| [PROPOSED_MODERATOR_REVIEW_MIGRATION.sql](sql/PROPOSED_MODERATOR_REVIEW_MIGRATION.sql) | Seventh table/RPC/trigger to implement TASK #39; **not part of baseline**, not executed |
| [PROPOSED_RESIDENT_SIGNUP_PROVISIONING.sql](sql/PROPOSED_RESIDENT_SIGNUP_PROVISIONING.sql) | Now **read-only checks**, because Auth-to-profile trigger already exists. Never install a second trigger |

## 1. Before applying anything

1. Use a local Supabase/PostgreSQL development stack or a **separately approved** staging project, **not** `epsvagztisdovixlqehi`. Creating a hosted project/branch might consume billable resources; review the actual plan/cost before proceeding.
2. Install supported Supabase CLI and Docker. **Supabase CLI v3 changed defaults in Nov 2026**: inspect `supabase --version` and `supabase --help`, then the relevant `db pull --help`/`migration --help`; never assume old commands/flags work unchanged.
3. Never place passwords, service-role keys, tokens, live Auth user data, private Storage files, or production connection strings in GitHub.
4. Back up the current project using Supabase's supported backup process before attempting any future remote schema changes.
5. Prefer a CLI-generated migration, using `supabase migration new <description>` or the supported `supabase db pull` workflow, to the hand-extracted draft. The catalog script is a **reviewable staging bootstrap**, not a replacement for a verified CLI migration.

Relevant official instructions: [Local development workflow](https://supabase.com/docs/guides/local-development/cli-workflows), [Pull schema](https://supabase.com/docs/reference/cli/supabase-db-pull), [Database migrations](https://supabase.com/docs/guides/local-development/database-migrations).

## 2. Fresh-environment test sequence (not yet performed)

1. Start a clean Supabase environment that has standard managed `auth`, `storage`, builtin roles and PostgreSQL 17. Do not test against an empty plain PostgreSQL instance without the Supabase services.
2. Review the baseline draft **especially SECURITY DEFINER functions, schema ownership, grants, and storage.objects RLS**. It mirrors current policies without silently hardening them. There may be SQL compatibility issues from fresh-service defaults or changes in Supabase. Resolve these first on staging.
3. Apply the baseline SQL from a privileged **staging** SQL editor/CLI and verify no errors. Do not treat the script as idempotent; it is intended for a new environment.
4. Apply the eight-category seed on staging; never copy private data or real users.
5. Run **BASELINE_READ_ONLY_VERIFICATION.sql** and check inventory: 6 RLS-enabled public tables, 8 functions, 13 public and 3 storage policies, unique storage path index, private bucket and resident creation trigger.
6. Create only **new test accounts** in staging. Verify Resident signup provisions one Resident profile, existing login/logout, cannot set privileged roles, report ownership, image privacy, staff claim and resolve, admin report assignment, and atomic claim conflicts.
7. Run the security, performance and health advisors. Fix unsafe permissions before declaring the environment safe; do not change live RLS merely to clear a warning.
8. Once the baseline is functioning, consider applying the **nine indexes** and **Moderator review migration** separately, each with rollback planning, review and tests from [MODERATOR_REVIEW_STAGING_TEST_PLAN.md](MODERATOR_REVIEW_STAGING_TEST_PLAN.md).
9. Capture evidence: migration creation command, actual generated migration(s), catalog output, tests passing, screenshots and GitHub Action logs. Commit migration files under `supabase/migrations/` **only once generated and verified by the CLI**, not merely by copying a draft into a timestamped filename.

## 3. What the reconstruction draft covers (and what it does not)

The draft mirrors current public application tables, PK/FK/CHECK constraints, the extra unique attachment-storage-path index, existing PostgreSQL functions, selected table/column grants and exact policy expressions. It also includes an Auth signup trigger and private photo bucket metadata. It **does not** contain passwords, session data, reports or photo bytes.

It does **not** capture all Supabase platform configuration, global Auth settings, JWT/email configuration, Storage API server configuration, default privileges outside the six application tables, Supabase-managed database setup, or CLI migration history. Its replayability **has not yet been proved** on a fresh environment.

**Special note about Data API behavior:** New `public` tables may not be automatically available to clients under Supabase's 2026 Data API grant changes. The draft grants `SELECT`/`INSERT` to `authenticated` for the needed original tables and enables RLS; verify actual exposure in staging. `anon` should never gain broad app-data access merely to make a failing UI query work. The proposed `report_reviews` table likewise needs explicit `GRANT SELECT` and RLS.

## 4. Why TASK #34 cannot be marked Done yet

- Full baseline has been captured and documented; however **no fresh-environment replay** or integration/negative-role test has succeeded.
- There is **no tracked migration history** on the remote project.
- Proposed new indexes, Moderator review, and any future signup changes are separate, not proven part of the deployed baseline.
- Team signoff is needed to make the final migration an assessed, reproducible deliverable.

Do not merge or close TASK #34 based only on the existence of this document. Its acceptance requires replay evidence.

## Automated PostgreSQL 17 smoke status

The [Database Baseline & Moderator Smoke workflow](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44956106507) **passed on 22 Nov 2026**. It uses disposable PostgreSQL 17 plus **minimal Supabase schema stubs** (not a real Supabase service) to verify SQL replay and synthetic role checks. The job includes the [proposed server-side report-validation script](sql/PROPOSED_REPORT_INPUT_VALIDATION.sql) before the proposed Moderator migration. These test results are strong first-stage syntax/authorization evidence, **not** proof that the project has a tested Supabase Auth/Storage/API deployment. A full local or approved staging Supabase replay remains the final acceptance gate.
