# FixMate — release readiness and lecturer handover (2026-11-22)

This is a **truthful release status**, not a declaration that all hosted acceptance work is complete.

## Approved scope

- Base scope: original FixMate multi-account mockup, GitHub **12 implementation Tasks (#30–#41)**, **22 Features**, and 6 Epics.
- Frontend: Flutter Android Resident/Staff and unified Flutter Web Resident/Staff/Moderator/System Admin, backed by Supabase Auth/RLS when configured.
- Design: original FixMate mockup colors / responsive layout / role-specific pages; no `internal practice` branding or fake live credentials.
- No-spend rule: existing GitHub Pages/Actions free allowances, existing Supabase no-cost limits, isolated Supabase CLI + Docker for local acceptance, no paid staging.

## Added product experience

1. **Contacts / Help / About** shared support page is reachable on sign-in and in all four authenticated workspaces through compact toolbars or Profile.
   - Contacts use the externally published Kauno kolegija accommodation-service email `apgyvendinimas@kaunokolegija.lt` and official directory URL `https://kaunokolegija.lt/english/dormitories/`; it is explicitly not presented as an official FixMate support desk.
   - Help explains reporting, tracking, photos, profile editing, password recovery and statuses.
   - About explains the four roles, purpose and role-scoped data access.
2. **Lithuanian + English**: Existing `app_lt.arb` / `app_en.arb` still power navigation. Shared `FixMateText` and `fmTr` cover role-specific texts, forms, tooltips, support and report/status labels. Global language actions are accessible before login and from every authenticated role, with local preference persistence via `shared_preferences`. Continue to test any server-generated and user-generated content without inventing translations.
3. **Unified web**: the same published web build permits Resident as well as Staff/Moderator/Admin, while backend RLS/RPC enforces role access.
4. **F06.2 Admin user roles**: People tab can choose a target user and confirm a role; proposed audited, role-checked RPC, no browser secret keys, no self-change, stale-role protection. Tested only against disposable local backend until authorized hosted rollout.
5. **F06.3 Categories**: Add/edit/deactivate/reactivate; rename versions category, preserving historical report names. Missing hosted RPC disables editing safely.
6. **F05.1 Notifications**: proposed SQL trigger stores owner-only in-app status notifications; Resident has an inbox and read controls. Missing hosted table shows an honest unavailable state.
7. **F05.2 Push**: **not complete**; free Firebase Cloud Messaging Spark plus secure Supabase Edge Function is selected, but Android Firebase app registration, token handling, sender secrets and real background-device acceptance remain outstanding. See `docs/F05_2_FREE_PUSH_REQUIREMENTS.md`.

## Feature lifecycle and board

Existing **12 Tasks remain Done** in the GitHub board. Of the 22 Features, the most recent implementation classification is:

- **12 Done**: #7, #8, #12, #13, #14, #18, #19, #20, #21, #22, #25, #29.
- **9 In Progress**: #9, #10, #11, #15, #16, #17, #23, #26, #28.
- **1 Todo**: #24 (true Android push).
- Six Epics remain open until their child Features are accepted. **#47 Release Gate** remains open/In Progress.
- If the GitHub Project V2 custom Status field is synchronized: 24 Done (Tasks + accepted Features), 10 In Progress (9 Features + gate), 7 Todo (6 Epics + push). GitHub Issue updates do **not** automatically imply the Project custom field was edited.

## Hosted Supabase preflight (read-only)

The existing hosted project still lacks the schema pieces for:

- report moderator reviews / review RPC
- user-avatar column and private bucket
- category management RPC
- user role management RPC and audit
- resident status notification table

Do not claim these features work on hosted production yet; newer Flutter screens must remain read-only or show unavailable messages when a required extension is absent. No destructive migrations, role changes, test accounts or mock data were applied to hosted Supabase.

## Go/no-go checks before calling final delivery Done

- [ ] Flutter static analysis and all unit/widget tests pass for exact final revision.
- [ ] Disposable local Supabase Auth, REST, RLS, Storage and **real Chrome E2E** pass for exact final revision; include language/support navigation and admin security checks.
- [ ] Android connected build passes; test on a real handset with at least Resident and Staff.
- [ ] GitHub Pages publishes the exact reviewed revision; test login and password reset with a controlled test email.
- [ ] Team/lecturer signs off on release gate #47, ensures recoverable hosted backup and reviews all additive-only migrations, with an agreed rollback strategy.
- [ ] Hosted role/configuration and RLS acceptance passes after approved additive migrations, without disturbing existing reports.
- [ ] Free Firebase Cloud Messaging project is configured, tokens registered and remote push tested on a device while app is closed.
- [ ] Manually synchronize any GitHub Projects V2 Status fields not automatically updated.

**Release decision as of file creation:** in development / release candidate under test, **not yet a fully hosted final product**. Avoid promises of completed delivery until this checklist is verified.
