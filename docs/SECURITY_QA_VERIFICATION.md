# FixMate — Security & QA Verification Summary

**Project:** FixMate – SmartDormApp  
**Date:** 21 November 2026  
**Status:** Evidence-based verification of the tested MVP workflows; **not** a full security audit or production release certification.

## Tested application and backend scope

- Resident interface built with Flutter; maintenance staff screens built with Flutter.
- Standalone admin web dashboard built with HTML, CSS, and JavaScript and connected to Supabase. **Technology note:** the backlog originally describes a Flutter Web admin panel, but the project team reported lecturer approval of the standalone HTML/CSS/JS implementation on 21 Nov 2026. Other security and functional checks remain outstanding.
- Supabase Auth, PostgreSQL with row-level security (RLS), Storage private bucket `report-photos`, and role-checked public/privileged RPC functions.

## Functional evidence

The latest reviewed Flutter CI runs for commit `b8803f0` completed successfully: [pull-request check](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44840755094) and [branch push check](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44840755397).


| Area | Evidence observed | Result |
| --- | --- | --- |
| Flutter tests | Earlier integration test evidence was **8/8 passed**; after the Flutter source was committed on `feature/flutter-resident-staff`, `flutter pub get` succeeded and `flutter test` reported **19/19 passed**. | Passed on the uploaded Flutter branch |
| Authentication and profile | Resident authenticated; profile role/name/building/room displayed from Supabase | Passed |
| Report submission | Report **#9**, `Broken bathroom light`, saved to `maintenance_reports` and appeared after application restart | Passed |
| Photo attachment | Report #9 JPG present in private Storage and referenced by `report_attachments` | Passed |
| Staff workflow | Report #9: `new → in_progress → resolved`, recorded in `report_status_history` | Passed |
| Internal maintenance note | Note `solved at 9` for report #9 saved to `report_notes` | Passed |
| Admin dashboard | Real report metrics and all three initial user roles displayed after an admin profile RLS policy fix | Passed |
| Admin assignment | Report **#11**, `sink`, assigned to maintenance staff, then claimed and resolved; both transitions recorded | Passed |

## Database access control checks

- RLS was confirmed enabled on all **six** public tables: `maintenance_categories`, `maintenance_reports`, `profiles`, `report_attachments`, `report_notes`, and `report_status_history`.
- `authenticated` users do not have table-wide `UPDATE` on `maintenance_reports`; tested column-level `UPDATE` privileges were **false** for all report columns.
- `profiles` grants tested: `role`, `id`, and `created_at` cannot be updated directly by `authenticated`; `full_name`, `building`, and `room_number` can be updated subject to RLS.
- `anon` cannot `EXECUTE` public `claim_maintenance_report`, `assign_maintenance_report`, or `resolve_maintenance_report` after privileges were restricted.
- The privileged private RPC implementations check role/ownership before changing assignments or status.
- A simulated resident attempting **Claim**, **Assign**, and **Resolve** received expected authorization errors from PostgreSQL: `Not authorized to claim reports`, `Not authorized to assign reports`, and `Not authorized`.

## Resident and attachment isolation checks

- A second real resident account saw **zero** reports belonging to the first resident in Flutter.
- After creating its own report, each resident saw only its own reports in the UI.
- Under a simulated authenticated database role for the second resident: **0** reports #9/#11, **1** own report, and **0** attachments of report #9 were visible.
- For report #9, an assigned staff identity could read **1** attachment and **1** Storage object under a simulated authenticated role.
- The owner resident could read **1** attachment and **1** photo but **0** internal staff notes.
- An orphaned attachment database row referencing a missing PNG was detected and removed; the existing JPG attachment and its Storage file remained intact.
- Storage policies were consolidated for `report-photos` with the current `RESIDENT_UUID/REPORT_ID/filename` layout.

## Security and QA limits / remaining work

1. Test negative operations with real staff/admin sessions, and validate each role across the public API, not solely simulated SQL claims.
2. Review all RPC function ownership, schema privileges, grants and security-definer behavior (including functions beyond the three tested operations).
3. Check orphaned Storage objects and attachment records after upload failures; ensure file upload and database insertion have reliable cleanup/retry behavior.
4. **Branch-level test run and CI are complete:** 19/19 Flutter tests passed in the cloned repository, and GitHub Actions passed on the Flutter PR branch. Re-run after merging and review the analyzer's 22 informational findings; do not claim the final merged source has been tested yet.
5. Verify mobile device builds and browser compatibility; only Chrome/Flutter Web evidence is recorded here.
6. Finish password-recovery flow, notifications, user/role administration, and other backlog features that have not been demonstrated.
7. **Framework approval reported:** on 21 Nov 2026 the project team confirmed lecturer acceptance of the standalone HTML/JS admin implementation. Document any formal written evidence if needed; this does not close functional or security gaps.
8. Use separate deployment configurations and do not publish `service_role`, `sb_secret_`, or other server-side secrets in source control.

## Evidence and traceability

The detailed **Security & QA Verification Report** is retained separately as a Word document in the project's ChatGPT files/Library. SQL outputs, Flutter test logs, and report #9/#11 workflow records were supplied during the project discussion. This summary records outcomes without claiming that every untested feature has been completed.

**Current repository state (verified 21 November 2026):** Flutter source is committed in `mobile/` on `feature/flutter-resident-staff` (commit `bd539ef`, plus CI workflow commits), Admin Web source is committed in `admin-web/` on `feature/admin-web-dashboard` (commit `c8b437f`), and documentation lives on `docs/security-qa-evidence-2026-11-21`. Draft PRs [#43 Flutter](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/43), [#44 Admin](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/44), and [#42 Docs](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/42) are open and not merged into `main`.

**Current next step:** Review the three draft PRs and acceptance criteria, complete remaining end-to-end permission tests, and then merge through the team's normal process; the admin technology choice has been approved according to the project team. Do not mark unverified features as complete.
