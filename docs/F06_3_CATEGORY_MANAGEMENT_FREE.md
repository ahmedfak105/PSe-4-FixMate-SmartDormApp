# FixMate — F06.3 Maintenance Category Management

## Product behavior

Reference: [Feature #28](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/28) and the original multi-account lecturer mockup.

The **Categories** section in the signed-in System Admin workspace supports:

- Add a named maintenance category.
- Enable / disable category availability for **new** Resident reports.
- Rename a category **without changing older reports**: when renamed, the old category is deactivated and a new row with a new ID is created. Old report FKs remain attached to the historical name.
- Show active and inactive entries to the authorized Admin, with clear state and confirmation before deactivation.
- No destructive DELETE button. No direct role editing or privileged keys in the browser.

The Resident report form continues to query active categories only. Existing reports may refer to deactivated historical IDs.

## Backend security

Migration: `supabase/migrations/20261122150000_category_management.sql`

- `public.can_manage_maintenance_categories()` checks the authenticated user's **actual** `public.profiles.role = 'system_admin'`, not editable user metadata.
- `public.manage_maintenance_category(p_category_id, p_name, p_is_active)` performs admin-only create, toggle or versioned rename transactionally.
- Both RPCs are security-definer functions with empty search paths and fully qualified referenced objects.
- Ordinary browser clients receive **no INSERT, UPDATE or DELETE table grants** for `maintenance_categories`; only the audited RPC can change it. RLS adds an admin-only SELECT policy for inactive categories.
- No changes to historical maintenance reports or report foreign keys.

## Existing hosted deployment

At the last read-only hosted inspection, `maintenance_categories` has eight active categories and just the `View active categories` SELECT RLS policy; the `authenticated` role has SELECT only. **The management RPC is not installed.**

The UI intentionally **fails closed** on older deployments. It shows active category names and a message that editing is not enabled yet; Create/Edit/Enable controls are disabled instead of allowing a broken or unauthorized write.

**Do not apply the migration to populated hosted Supabase solely to make the UI active.** #47 still requires the safe additive rollout, verified backup/restore, and explicit production approval. All development can use local Supabase CLI + Docker in the free CI quota.

## Disposable local acceptance tests

- `docs/sql/test/local_supabase_api_smoke.sh`: real Supabase REST/Auth tests for system-admin capability, denied Resident/Staff/Moderator and direct table writes, create, rename, historical report FK/name, deactivate/reactivate, inactive Resident visibility and invalid name rejection.
- `mobile/test/admin_categories_test.dart`: input validation tests.
- `mobile/integration_test/operations_e2e_test.dart`: real Chrome UI creates and renames a category using the authenticated System Admin account; verifies both historical and current rows.

### Hosted release checklist

- [ ] Free local REST/Auth and Chrome E2E category tests pass on the release commit.
- [ ] Preflight the existing hosted schema and RLS; check for conflicting category names or permissions.
- [ ] Make a verified backup/recovery plan for populated hosted data under release gate #47.
- [ ] Apply the single reviewed **additive-only** migration without replaying baseline.
- [ ] Verify admin-only category management through the live connected web UI.
- [ ] Verify a resident cannot write categories or see inactive categories; old reports retain old category names.
- [ ] Only then mark Feature #28 Done. Keep Epic #6 open until its other Feature acceptance criteria pass.

No billable Supabase staging branches or external commercial tools are required.
