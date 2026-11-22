# FixMate TASK #39 — Moderator Review: Staging Deployment & Test Plan

**Status (21 November 2026):** Code committed; **NOT deployed** to the active Supabase project; no moderator end-to-end test yet.

**Task acceptance source:** [TASK #39](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/39) / Feature F03.2. Approved task asks for new-report queue, report details, category/description/photo, valid/duplicate/inappropriate actions, role checks, and persisted review outcomes.

## Delivered source

- [Proposed SQL migration](sql/PROPOSED_MODERATOR_REVIEW_MIGRATION.sql) on PR #42.
- [Moderator web page](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/blob/feature/admin-web-dashboard/admin-web/moderator.html) and [browser logic](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/blob/feature/admin-web-dashboard/admin-web/moderator.js) on PR #44.
- Updated login routing in `admin-web/app.js` sends role `moderator` to `moderator.html`. Admin accounts may open the same review page.
- Admin Web CI checks JavaScript syntax and required references. Green CI does **not** prove Supabase authorization.

## Proposed schema change (not part of the original verified six-table snapshot)

The proposed migration adds **one** `public.report_reviews` table, one SELECT RLS policy, the authenticated-only `public.review_maintenance_report` wrapper and a protected internal routine. The new `report_reviews` table stores:

| Column | Purpose |
|---|---|
| `report_id` | PK / FK to `maintenance_reports`; one final review per report |
| `reviewer_id` | FK to existing `profiles`; author of review |
| `outcome` | `valid`, `duplicate`, or `inappropriate` |
| `reason` | Optional for valid, mandatory for duplicate/inappropriate; at most 500 chars |
| `reviewed_at` | Timestamp |

The migration keeps `maintenance_reports.status` at `new`, `in_progress`, `resolved`, so legacy Flutter staff and resident status mapping does not change. A trigger rejects attempts to assign or claim reports reviewed as duplicate/inappropriate. Review and existing claim/assign calls lock the same report row, preventing a valid review of an already-assigned report and avoiding decision/claim races.

**Caution:** Existing documentation's six-table counts and policy inventory describe the current pre-migration Supabase snapshot. **Only after deployment and verification** should they be updated to include the new table/policy/functions.

## Before any deployment

1. Obtain and verify a Supabase **staging/clone** with the current FixMate schema, RLS, functions and **test** accounts (resident, maintenance_staff, moderator, system_admin). No production user data.
2. Review every statement in `PROPOSED_MODERATOR_REVIEW_MIGRATION.sql`, especially `SECURITY DEFINER` function ownership, `EXECUTE`/schema privileges, RLS, trigger, and any pre-existing trigger or policy interactions. Do not paste any server-side API keys into browser code.
3. Back up staging and apply the migration in **one transaction**. Confirm `report_reviews` exists, RLS enabled, policy and functions installed. Do **not** run the six-table reconstruction reference SQL.
4. Start `admin-web/` with a local HTTP server and sign in with test users. Use the same `https://....supabase.co` URL as staging (not the active production project).

## Functional and security acceptance checks

| ID | Test action | Expected result |
|---|---|---|
| M1 | Sign in as moderator through `index.html` | Redirect to `moderator.html` |
| M2 | Sign in as system_admin and open `moderator.html` | Authorized to read and review |
| M3 | Try `moderator.html` as resident or maintenance_staff | Access denied by UI; direct RPC must also be forbidden |
| M4 | Create new unassigned report as resident | Listed in Awaiting review with title, category, date, description, location |
| M5 | Add a JPEG/PNG/WebP to a report | Moderator can view private image only with authorized Storage access |
| M6 | Review report as `valid` | `report_reviews` row created with reviewer/timestamp; report remains `new` |
| M7 | Review another report as `duplicate` with reason | Decision persisted; staff/admin assignment/claim fails |
| M8 | Review another report as `inappropriate` with reason | Decision persisted; staff/admin assignment/claim fails |
| M9 | Try duplicate/inappropriate with blank reason or >500 chars | Validation error, no review row |
| M10 | Attempt a second review of the same report | Returns `false` and preserves original review |
| M11 | Attempt review after staff has claimed/been assigned a report | Returns `false`; no review row |
| M12 | Test concurrent claim and review on same new unassigned report | Exactly one takes effect; no rejected report becomes assigned |
| M13 | Test a normal, non-rejected report claim and resolution after migration | Existing staff workflow still works |
| M14 | Query `report_reviews` as resident and staff through ordinary authenticated API | Review rows not returned by RLS |
| M15 | Call `review_maintenance_report` with `anon`/no user | Execution denied |
| M16 | Visit `moderator.html` with missing migration | Clear error, never pretends a review was saved |

## Proof required before closing TASK #39

- Screenshots of moderator report queue, attached photo, valid/duplicate/inappropriate decisions and saved outcomes.
- Read-only SQL output showing relevant `report_reviews` rows, PK/FKs/checks, RLS and role grants **after** staging migration.
- Negative authenticated API calls with test resident and staff (not just simulated SQL Editor identities).
- Concurrency/assignment tests for rejected reports, and a regression test for normal claim/resolve.
- Verified review history does not expose private notes or privileged credentials.

**Important:** A SQL Editor query often runs with elevated database privileges and is **not** evidence that a resident can or cannot access a row via the actual authenticated API.

## Scope decisions to document

- This design permits **one immutable review per report**. Appeals/re-review would need a separately approved change.
- Review is limited to new unassigned reports. If a report has already been claimed, it is not reviewable in this first implementation.
- Rejected reports remain operationally `new` but are blocked from work by the database trigger. Staff queue UX may still display them before a filter is added; the backend does not allow the claim.
- Review decisions do not automatically send a resident notification; notifications are a separate backlog feature.

**No live Supabase schema or data change is claimed by this file.**

## New automated evidence (22 November 2026)

A [PostgreSQL 17 smoke job](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44956106507) now passes after applying the proposed review migration on an **ephemeral database** with synthetic Auth/Storage stubs. It tests moderator/admin review outcomes, rejection reasons, one-decision-only behavior, denied resident review, private review metadata, rejected-report claim prevention, and normal claim/resolve. This verifies PostgreSQL logic only; it **does not verify Supabase Auth API, real photo download, UI interactions, or concurrent separate transactions**. The migration remains undeployed on the live Supabase project; TASK #39 stays In Progress.

## Local replay complete; hosted gate remains — 22 Nov 2026

The Moderation table, review RPC and guard are now the **fifth** ordered Supabase CLI migration `supabase/migrations/20261122000340_fixmate_moderator_review.sql` and rebuild automatically with the other four migrations in a fresh local project. [Real Flutter Web Chromium review E2E passed](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44964869271), [local Auth/Storage API tests passed](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44964866869), and [one-command lecturer demo reproduction passed](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44964866875). Original TASK #39 is **closed as locally implemented/tested**, while this document's project-specific hosted staging/deployment checks are still required under [RELEASE GATE #47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47). **The original remote project remains unchanged.**
