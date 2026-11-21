# FixMate — Supabase Row-Level Security Architecture

**Project:** FixMate – SmartDormApp  
**Scope:** `public` schema, six application tables  
**Evidence date:** 2026-11-21  
**Evidence source:** SQL Editor exports of `pg_class` and `pg_policies`, plus `has_table_privilege`, `has_column_privilege` and `pg_trigger` catalog checks supplied by the project team.

> **Evidence-based documentation, not a security certification.** Policy definitions and table flags were observed. Basic `profiles` UPDATE privileges and user-defined triggers have also been checked. RPC metadata and EXECUTE permissions have now also been checked. Function bodies and schema USAGE grants have now also been reviewed; function ownership, Storage RLS, effective API exposure, and end-to-end RPC authorization tests still require verification. The checks below must be run with an account that can inspect catalog metadata.

## Overview

All **6 / 6** application tables have `relrowsecurity = true`. The export contains **13** RLS policies. For all six tables, `relforcerowsecurity = false`: ordinary RLS applies to configured client roles, while PostgreSQL table owners and roles with appropriate bypass privileges can be exempt.

| Table | RLS enabled | Policy count | Operations observed |
|---|---|---:|---|
| `maintenance_categories` | Yes | 1 | SELECT |
| `maintenance_reports` | Yes | 3 | SELECT, INSERT |
| `profiles` | Yes | 3 | SELECT, UPDATE |
| `report_attachments` | Yes | 3 | SELECT, INSERT |
| `report_notes` | Yes | 2 | SELECT, INSERT |
| `report_status_history` | Yes | 1 | SELECT |

All listed policies target PostgreSQL role `authenticated`. The application-level roles visible in the `profiles.role` CHECK constraint are `resident`, `maintenance_staff`, `moderator` and `system_admin`.

## Exact policy names and observed behavior

### 1. `maintenance_categories`
- **View active categories** — SELECT for authenticated users, with `USING (is_active = true)`. Inactive categories are hidden through this policy.

### 2. `maintenance_reports`
- **Residents create reports** — INSERT checks that `resident_id = auth.uid()`, `status = 'new'`, `assigned_to IS NULL`, and the acting profile has `role = 'resident'`.
- **Residents view own reports** — SELECT only when `resident_id = auth.uid()`.
- **Staff and admins view reports** — SELECT permits maintenance staff to see *unassigned new* reports or reports assigned to themselves; `moderator` and `system_admin` profiles can see reports through this policy.

No direct UPDATE or DELETE policy for `maintenance_reports` appeared in the export. Staff claim/status changes may use protected database functions, but **that cannot be concluded from these policies alone**.

### 3. `profiles`
- **FixMate admins can view all profiles** — SELECT using `fixmate_private.current_user_is_system_admin()`. The helper's implementation was not supplied.
- **View own profile** — SELECT when `id = auth.uid()`.
- **Update own profile** — UPDATE using and checking only `id = auth.uid()`.

**Role-column authorization verified:** the UPDATE policy checks row ownership, but grants limit which columns can be changed. The team's read-only privilege query returned `authenticated` table UPDATE = `false`, `role` column UPDATE = `false`, `full_name` column UPDATE = `true`, and user-defined triggers = `[]`. Thus direct self-promotion through an `authenticated` UPDATE of `profiles.role` is **not permitted by the checked grants**; updating the allowed `full_name` field remains subject to the own-row RLS policy. This does not establish the safety of privileged RPC functions or other indirect write paths.

### 4. `report_attachments`
- **FixMate view report attachments** — SELECT if a corresponding row exists in `maintenance_reports`. Visibility of that referenced report is subject to the effective privileges/RLS of the querying context.
- **fixmate_resident_select_attachments** — SELECT if the linked report's `resident_id = auth.uid()`.
- **fixmate_resident_insert_attachments** — INSERT requires `uploaded_by = auth.uid()`; exactly two storage path segments; first segment matches the user's UUID, second matches `report_id`; the report belongs to the authenticated resident; and a matching object is present in the `report-photos` Storage bucket.

Multiple permissive SELECT policies can combine with OR. The broader and narrower attachment SELECT rules should therefore be assessed together, not separately. Storage bucket access needs its own `storage.objects` policy review.

### 5. `report_notes`
- **Staff add internal notes** — INSERT requires `author_id = auth.uid()`, nonempty trimmed content, and either an admin/moderator role or `maintenance_staff` assigned to the report.
- **Staff read internal notes** — SELECT uses the corresponding admin/moderator or assigned-maintenance-staff rule.

No resident note-access policy was listed.

### 6. `report_status_history`
- **View history of visible reports** — SELECT requires a linked row to exist in `maintenance_reports`. Its effective visibility depends on permissions/RLS of the referenced reports.

No direct INSERT/UPDATE/DELETE policy was listed for history. The existence, behavior and permissions of any history-writing triggers or RPCs remain unverified.

## Role-based access summary

| Application role | Reports visible through exported policies | Internal notes |
|---|---|---|
| Resident | Own reports | No policy granting access |
| Maintenance staff | New unassigned reports and their own assigned reports | Own assigned reports only |
| Moderator | Reports via staff/admin SELECT policy | Admin/moderator access |
| System admin | Reports via staff/admin SELECT policy | Admin/moderator access |

The `profiles` admin SELECT policy additionally exposes all profiles *if* its helper returns true. The admin UI has also been observed denying a signed-in `maintenance_staff` user and allowing `system_admin` access; this is a UI/role-gate observation, **not a substitute for direct database authorization testing**.

## Verified: can an ordinary user directly edit `profiles.role`?

A **read-only** catalog query supplied by the team on 2026-11-21 returned:

| Check | Result | Interpretation |
|---|---|---|
| `has_table_privilege('authenticated', 'public.profiles', 'UPDATE')` | `false` | No general table-level UPDATE grant |
| `has_column_privilege('authenticated', 'public.profiles', 'role', 'UPDATE')` | `false` | No direct UPDATE permission on role column |
| `has_column_privilege('authenticated', 'public.profiles', 'full_name', 'UPDATE')` | `true` | Column-specific UPDATE permission on full_name |
| User-defined `pg_trigger` entries on `public.profiles` | `[]` | No non-internal triggers found |

**Conclusion:** In the inspected grants, an ordinary `authenticated` database role cannot directly modify `profiles.role` via an UPDATE statement. RLS further restricts updates of permitted profile fields to the current user's own row. Review RPC functions and EXECUTE permissions before making a system-wide authorization claim.

The query used was:

```sql
SELECT
  has_table_privilege('authenticated', 'public.profiles', 'UPDATE') AS table_update_allowed,
  has_column_privilege('authenticated', 'public.profiles', 'role', 'UPDATE') AS role_update_allowed,
  has_column_privilege('authenticated', 'public.profiles', 'full_name', 'UPDATE') AS full_name_update_allowed,
  (
    SELECT COALESCE(jsonb_agg(pg_get_triggerdef(t.oid, true)), '[]'::jsonb)
    FROM pg_trigger AS t
    WHERE t.tgrelid = 'public.profiles'::regclass
      AND NOT t.tgisinternal
  ) AS profile_triggers;
```

## Verified RPC function metadata (2026-11-21)

Source: SQL Editor export from `pg_proc` and `pg_namespace`. **These results describe function metadata and PostgreSQL role EXECUTE grants, not yet the internal authorization logic.**

| Schema | Function signature | Security mode | EXECUTE: authenticated | EXECUTE: anon |
|---|---|---|---|---|
| `fixmate_private` | `assign_maintenance_report(bigint, uuid)` | DEFINER | true | false |
| `fixmate_private` | `claim_maintenance_report(bigint)` | DEFINER | true | false |
| `fixmate_private` | `current_user_is_system_admin()` | DEFINER | true | false |
| `fixmate_private` | `resolve_maintenance_report(bigint)` | DEFINER | true | false |
| `public` | `assign_maintenance_report(bigint, uuid)` | INVOKER | true | false |
| `public` | `claim_maintenance_report(bigint)` | INVOKER | true | false |
| `public` | `resolve_maintenance_report(bigint)` | INVOKER | true | false |

All seven functions return `boolean` and report `search_path=""` in their function settings. The private implementations run with function-owner privileges, while the public functions use invoker privileges. This pattern may implement a restricted public RPC layer forwarding requests to privileged internal functions, but **the actual bodies have not yet been inspected**.

**Security interpretation:**
- `anon` has no EXECUTE privilege according to the supplied check.
- `authenticated` has EXECUTE privilege on all seven, but invoking a function can additionally depend on schema USAGE privileges; investigate `has_schema_privilege` on `fixmate_private`.
- A role-level EXECUTE grant is **not** sufficient proof that the caller can claim, assign or resolve any report: the body must validate the current user's application role and the relevant report state/ownership.
- Before approving `SECURITY DEFINER` code, inspect `pg_get_functiondef` and verify explicit schema-qualified object references, role checks, report-state guards, and the security of any nested calls.
- Do not claim privilege-escalation protection for RPC until those checks are complete.

## Verified RPC implementation logic (SQL definitions reviewed, 2026-11-21)

The project team supplied `pg_get_functiondef` output for all seven previously inventoried functions, plus `has_schema_privilege('authenticated', ..., 'USAGE')` results. The `authenticated` PostgreSQL role has **USAGE on both `public` and `fixmate_private`**. The three public `SECURITY INVOKER` functions call the corresponding `fixmate_private` functions by fully qualified schema name. The four private routines execute as `SECURITY DEFINER`, use `SET search_path TO ''`, and reference `auth.uid()`, `public.profiles`, `public.maintenance_reports`, and `public.report_status_history` by qualified names.

### Access rules visible in the code

| Function | Caller role check in body | Report/target requirement | Result/side effect |
|---|---|---|---|
| `fixmate_private.claim_maintenance_report(bigint)` | Current `auth.uid()` must belong to `maintenance_staff` | Report must be `new` and either unassigned or already assigned to same caller | Atomically sets `assigned_to`, `status = in_progress`, inserts a `new → in_progress` history row; returns true, or false if no qualifying report |
| `fixmate_private.assign_maintenance_report(bigint, uuid)` | Current caller must be `moderator` or `system_admin` | Target UUID must represent `maintenance_staff`; report must be `new` and unassigned | Sets `assigned_to` without changing report status; returns true, or false if no qualifying report |
| `fixmate_private.resolve_maintenance_report(bigint)` | Current caller must belong to `maintenance_staff` | Report must be `in_progress` and assigned to this caller | Sets status to `resolved`, inserts an `in_progress → resolved` history row; returns true, or false if no qualifying report |
| `fixmate_private.current_user_is_system_admin()` | Checks caller profile `role = system_admin` | Profile must match `auth.uid()` | Returns true only for matching admin profile |

The three `public` functions (`claim_maintenance_report`, `assign_maintenance_report`, `resolve_maintenance_report`) are thin SQL wrappers of their corresponding private functions. All seven use qualified function/table names and empty `search_path` settings.

**Observations and boundaries:**
- Report claims use a single conditionally executed `UPDATE ... WHERE status = 'new' ... RETURNING id`. Competing claims on one initially unassigned report cannot both successfully transition that same report from `new`; the state and row-lock behavior prevent the loser from passing the condition after the winner commits.
- The claim and resolve operations insert history rows in the **same function transaction** as the status transition; exceptions during history insertion would roll back the whole operation.
- Manager assignment intentionally retains `new` status, so the nominated staff member still needs to claim the report to move it to `in_progress`.
- There is **no per-staff active workload limit** in the reviewed claim function: an authorized worker may claim multiple distinct eligible reports. Whether this is desirable is a product requirement.
- The authorization checks reference the `profiles.role` column. Earlier permission checks found no `authenticated` UPDATE privilege on that column.
- `authenticated` also has private-schema USAGE and private-function EXECUTE. The role checks inside the `SECURITY DEFINER` functions therefore matter even for calls made outside the public wrappers. Public API exposure of the private schema was **not** established by the export and should be checked separately.
- Code review supports the listed role and report-state protections, but **does not replace live negative tests for unauthorized access or a complete security audit**.

## Storage bucket configuration verified (2026-11-21)

The team supplied this **read-only** SQL Editor result for `storage.buckets`:

| Setting | Observed value |
|---|---|
| Bucket ID and name | `report-photos` |
| Public bucket | `false` (private bucket) |
| File size limit | `5242880` bytes = **5 MiB** |
| Allowed MIME types | `image/jpeg`, `image/png`, `image/webp` |

**Storage policies have now been reviewed (see below).** A private bucket does not on its own establish per-user isolation; effective storage-object RLS and authorization should also be checked.

## Verified Storage object policies (2026-11-21)

The team supplied three policy definitions from `pg_policies` for `storage.objects`, all scoped to PostgreSQL role `authenticated`. There were two `SELECT` policies and one `INSERT` policy, with no `UPDATE` or `DELETE` policy in the supplied export.

| Policy | Command | Evidence-based access rule |
|---|---|---|
| `fixmate_resident_read_photos` | SELECT | Bucket must be `report-photos`; first folder name equals `auth.uid()`; second folder names a report whose `resident_id` matches the caller |
| `fixmate_resident_upload_photos` | INSERT | Bucket must be `report-photos`; first folder name equals `auth.uid()`; second folder names a report whose `resident_id` matches the caller |
| `fixmate_staff_admin_read_photos` | SELECT | Bucket must be `report-photos`; path must have exactly two folders; first folder must match `maintenance_reports.resident_id` and second folder the report ID; maintenance staff require `assigned_to = auth.uid()`, while `moderator` and `system_admin` roles are permitted |

**Implications:** A resident's read/upload access is tied to ownership of the referenced report. Maintenance staff can read photos tied to their own assigned reports; moderator and system admin roles can read report photos via the staff/admin policy. The latter policy explicitly validates two folder segments. None of these observed policies independently allows unauthenticated access.

**Review notes:**
- The resident upload policy checks ownership but does **not** explicitly check that the caller's profile role is `resident`. If former residents retain ownership of reports after role changes, the ownership-only rule would still match.
- The resident read/upload policies do **not** require an exact folder count. For example, a path containing further nested subfolders may match their first two folder checks. The staff/admin SELECT policy requires exactly two folders, and `report_attachments` metadata INSERT policy also checks exactly two folders. This inconsistency may permit additional storage objects outside the normal app metadata format. Review and test before tightening rules to avoid breaking existing object paths.
- Multiple permissive RLS SELECT policies can combine with OR. The rules above have been interpreted together.
- **The subsequent catalog check confirmed `storage.objects.relrowsecurity = true`; effective SELECT/INSERT grants and the anon SELECT grant are documented below.**
- No direct authenticated negative tests for unauthorized photo reads/uploads were supplied in this step. Code/policy review is not a penetration test.



## Verified storage.objects table privileges and RLS status (2026-11-21)

A subsequent read-only SQL Editor query of `pg_class` and `has_table_privilege` returned:

| Catalog check | Value | Meaning |
|---|---|---|
| `rls_enabled` | `true` | RLS is enabled on `storage.objects` |
| `rls_forced` | `false` | Ordinary RLS rules apply; owner/bypass exceptions remain |
| `authenticated_can_select` | `true` | Table SELECT privilege exists, still subject to RLS |
| `authenticated_can_insert` | `true` | Table INSERT privilege exists, still subject to RLS |
| `anon_can_select` | `true` | Anonymous PostgreSQL role has table SELECT privilege; **not equivalent to permission to read rows** |

**Security interpretation:** All three enumerated `storage.objects` policies are directed to the `authenticated` role, and none authorizes the `anon` role. Under the observed ordinary RLS setup, a non-bypass `anon` request should be filtered from the stored photo rows despite the underlying SELECT grant. The `report-photos` bucket is also private. This is an evidence-based expectation, **not a completed anonymous-access test**. Avoid claiming that `anon_can_select = true` is an exposed-photo vulnerability without verifying effective row access. Conversely, do not claim all Storage endpoints are secure without exercising direct anonymous and cross-user download/list tests.

**No GRANT or RLS policy changes were made** based on this inspection. Catalog review alone is not a production security audit.

## Remaining evidence needed before claiming full security verification

1. Perform direct anonymous (without login) and cross-account Storage list/read/upload negative tests; the `storage.objects` RLS flag and relevant table grants are now verified.
2. Run live direct-API negative tests for each role and RPC path (beyond UI denial), including unassigned/assigned reports and invalid role transitions.
3. Confirm API-exposed schemas, function owner roles and effective runtime privileges for `SECURITY DEFINER` routines.
4. Gather database indexes, remaining schema triggers and additional objects for a full deployment/backup script.

**Documentation status:** Evidence gathered and organized; security review is ongoing.
