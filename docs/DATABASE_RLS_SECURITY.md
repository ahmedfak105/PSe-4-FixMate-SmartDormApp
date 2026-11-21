# FixMate — Supabase Row-Level Security Architecture

**Project:** FixMate – SmartDormApp  
**Scope:** `public` schema, six application tables  
**Evidence date:** 2026-11-21  
**Evidence source:** SQL Editor export of `pg_class` and `pg_policies` supplied by the project team.

> **Evidence-based documentation, not a security certification.** Policy definitions and table flags were observed. Database grants, triggers, helper function definitions, Storage RLS and RPC authorizations were *not* included in this export and require separate checks. The checks below must be run with an account that can inspect catalog metadata.

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

**Important authorization question:** the UPDATE policy checks *row ownership*, not whether the `role` column remains unchanged. If `authenticated` can UPDATE `profiles.role` and no trigger or other database guard blocks that change, a user could potentially promote their own profile to `system_admin`. **This is a potential risk, not a confirmed vulnerability.** Verify column privileges and update triggers before claiming RBAC protection is complete.

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

## Priority verification: can an ordinary user edit `profiles.role`?

Run this **read-only** query in Supabase SQL Editor; do not change any permissions yet:

```sql
SELECT
  has_table_privilege('authenticated', 'public.profiles', 'UPDATE')
    AS authenticated_table_update,
  has_column_privilege('authenticated', 'public.profiles', 'role', 'UPDATE')
    AS authenticated_role_update,
  has_column_privilege('authenticated', 'public.profiles', 'full_name', 'UPDATE')
    AS authenticated_full_name_update,
  (
    SELECT COALESCE(jsonb_agg(pg_get_triggerdef(t.oid, true)), '[]'::jsonb)
    FROM pg_trigger AS t
    WHERE t.tgrelid = 'public.profiles'::regclass
      AND NOT t.tgisinternal
  ) AS profiles_user_triggers;
```

If `authenticated_role_update = true`, carefully review the trigger implementations and test a role-change attempt in an isolated test account before concluding escalation is possible or impossible. Do **not** grant additional UPDATE rights or run an actual role-changing UPDATE during this catalog inspection.

## Remaining evidence needed before claiming full security verification

1. `profiles` column-level UPDATE privileges and relevant trigger definitions.
2. `pg_proc` metadata and authorizations for claim, assign, resolve and `fixmate_private.current_user_is_system_admin()` functions; check `SECURITY DEFINER`, search path, and EXECUTE grants.
3. `storage.objects` RLS and the `report-photos` bucket privacy settings.
4. Direct API negative tests for each role (not just UI gate tests).
5. Database indexes, triggers and any additional schema objects for a full deployment/backup script.

**Documentation status:** Evidence gathered and organized; security review is ongoing.
