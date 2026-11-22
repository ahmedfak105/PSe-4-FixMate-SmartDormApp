# FixMate — lecturer mockup and issue acceptance map (zero-cost development)

This is a source-alignment document, not proof that all features have shipped.

## Original design reference

The **FixMate_Multi_Account_Interactive_Mockup.html** (the app-only, multi-account version used for lecturer review) is the authoritative interaction/design reference. Earlier prototypes are **FixMate_Interactive_Mockup.html**, **FixMate_Complete_Interactive_Mockup.html** and **FixMate_Offline_Interactive_Mockup.html**. Source artifacts were recovered from the project file library, not reconstructed from screenshots.

Original multi-account mockup design tokens:

- Background `#eef4f5`, surface `#ffffff`, secondary surface `#f6fbfa`.
- Border `#dbe8e8`, primary ink `#18323f`, muted text `#6b7f8d`.
- Primary teal `#127f76`, darker teal `#0d675f`, mint `#dff5ed`.
- Accent amber `#eba654`, error `#c55e69`, rounded cards circa 20–22px.
- Web: top brand bar, optional left sidebar on desktop, dashboard summary metrics, report list/details, management tables; mobile: role-specific bottom navigation, cards, status badges, personal profile.

Mockup interactions include per-account login and private views; Resident Home/New/My Reports/Profile; Staff Home/Queue/My Tasks/Profile; Moderator Home/Review/Reports/Profile; Admin Web dashboard and management; role-specific actions, status progress, notifications and profile settings. The mockup uses eight **fictional** accounts and localStorage; these are visual/behavior examples and MUST NOT be copied into live authentication or displayed as real accounts.

**Product UX:** Only `FixMate` / `FixMate Operations` branding appears to authenticated users. No lecturer guidance, `internal practice`, fake success signals, simulated approvals, mock credentials, or offline-demo banners in the connected product. The explicitly offline standalone demo may retain an honest `DEMO DATA` label.

## GitHub acceptance scope

The agreed GitHub issues (12 TASKs and 22 Features under six Epics) take precedence over invented functionality. The original issue descriptions are authoritative for acceptance criteria, especially:

| Workstream | Issue references | Expected user outcomes |
|---|---|---|
| Authentication/profile | F01.1–F01.5 (#7–#11), TASK #29/#34 | Registration, sign-in/out, password recovery, role-safe profiles, self-service name/building/room |
| Resident reporting | F02.1–F02.4 (#12–#15), TASK #30/#31/#35 | New report with category/validation/optional attachment and correct owner |
| Staff/moderation | F03.1–F03.5 (#16–#20), TASK #36/#38/#39/#40 | Authorized list/review/claim/status/notes with server-side enforcement |
| Resident tracking | F04.1–F04.2 (#21–#22), TASK #32 | Own reports, detail, status and history |
| Notifications | F05.1–F05.2 (#23–#24) | Status notifications and, separately, push delivery; verify separately, don't claim ready merely because planned |
| Admin | F06.1–F06.4 (#25–#28), TASK #37 | Real metrics, users/roles, categories, filters respecting permissions |

Backlog FEATURES may be incomplete even when original implementation TASKs pass. In particular, do not mark role administration, notifications or full category management complete without their acceptance tests.

## Cost and safety constraints

1. **No paid services or billable Supabase branches/projects.** Isolated, zero-cost GitHub Actions with disposable local Supabase CLI + Docker and PostgreSQL are the default staging/testing solution. Use existing GitHub Pages for public web hosting, subject to its free-tier conditions.
2. Existing hosted Supabase is populated and has migration drift; NEVER reset it or replay baseline schema. Don't migrate hosted moderation or avatar storage until the additive SQL, isolated API tests, backup/recovery and release gate #47 are satisfied.
3. Only the current user's name/building/room/avatar may be edited via self-service; email/role/id remain privileged. Keep private media under role/owner RLS.
4. Do not introduce mock passwords/users into hosted Supabase. Show actual, role-filtered records only.
5. Store verification in GitHub CI logs; report explicitly what passed, what's pending and what remains hosted-only.
6. Prefer free built-in Flutter Material widgets, project-approved Supabase free resources, GitHub Actions and GitHub Pages over third-party paid UI, notifications or test platforms.

## Release checklist

- Flutter `analyze` and unit/widget tests green.
- Chrome role-navigation E2E against a **local disposable** Supabase stack green.
- API tests verify Resident/Staff/Moderator/Admin self-profile edits, cross-account rejection, role escalation rejection, private avatar upload/download and denial of cross-account reads.
- Web build has a project-relative Pages base href, contains only public publishable key and deploys from approved branch.
- Connected Android build tested separately; don't mistake offline APK for the hosted-connected release.
- Hosted schema verified read-only before each approved additive migration.
