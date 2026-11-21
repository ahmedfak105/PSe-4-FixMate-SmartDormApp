# FixMate — Supabase Row-Level Security Architecture

**Project:** FixMate – SmartDormApp  
**Scope:** `public` schema, six application tables  
**Evidence date:** 2026-11-21  
**Evidence source:** SQL Editor exports of `pg_class` and `pg_policies`, plus `has_table_privilege`, `has_column_privilege` and `pg_trigger` catalog checks supplied by the project team.

> **Evidence-based documentation, not a security certification.** Policy definitions and table flags were observed. Basic `profiles` UPDATE privileges and user-defined triggers have also been checked. RPC metadata and EXECUTE permissions have now also been checked. Function bodies, schema USAGE grants, other grants, Storage RLS and end-to-end RPC authorizations still require separate checks. The checks below must be run with an account that can inspect catalog metadata.

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

## Remaining evidence needed before claiming full security verification

1. Inspect all seven RPC function bodies and verify each role/ownership/state check, plus `fixmate_private` schema USAGE grants and actual callable access.
2. `storage.objects` RLS and the `report-photos` bucket privacy settings.
3. Direct API negative tests for each role (not just UI gate tests).
4. Database indexes, other schema triggers and any additional schema objects for a full deployment/backup script.

**Documentation status:** Evidence gathered and organized; security review is ongoing.
