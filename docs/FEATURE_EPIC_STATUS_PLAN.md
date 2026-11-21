# FixMate — Feature and Epic Status Reconciliation

**Evidence snapshot:** 21 November 2026  
**Source:** Actual feature/epic acceptance criteria in GitHub Issues #1–#29; committed Flutter MVP in PR #43; admin dashboard in PR #44; verified SQL/ERD/RLS/RPC/Storage evidence in PR #42.  
**Project Board:** The existing GitHub Project board may contain **copied issues from the lecturer's repository with different issue numbers**. Match tasks by **issue title / feature ID**, never copy an issue number from the student repository into the lecturer's project.

> The classifications below are proposals to synchronize the **GitHub Project Status field**, not assertions that draft PRs have been merged or the product is production-ready. `Done` means the stated Feature acceptance criteria are met in the observed MVP. The project team reports that the lecturer approved the standalone HTML/CSS/JS admin technology on 21 Nov 2026; implementation scope and other acceptance criteria still need review. `Todo` = not yet demonstrated; `In Progress` = implemented in part; `Done` = demonstrably meets criteria.

## Epic status matrix

| Epic | Proposed Status | Reason |
|---|---|---|
| **EPIC-01: User Authentication & Access Control** | **In Progress** | Login/logout and role restrictions exist; sign-up, password recovery and profile edits are incomplete |
| **EPIC-02: Maintenance Issue Reporting** | **In Progress** | Submission, photos and categories work; complete field-length validation still needs work |
| **EPIC-03: Maintenance Report Management** | **In Progress** | Staff claim/resolve/notes work; moderator-specific review is missing and web-staff requirements need review |
| **EPIC-04: Resident Report Tracking** | **In Progress** | My Reports/details work, but submission dates are not displayed in the relevant Flutter screens |
| **EPIC-05: Notifications** | **Todo** | Neither report-change notifications nor push delivery has been demonstrated |
| **EPIC-06: Administration & System Configuration** | **In Progress** | Dashboard, report search and assignment work; privileged user and category management are missing |

## Feature status matrix — all 22 items

| Feature | Proposed Status | Direct evidence and outstanding acceptance |
|---|---|---|
| **F01.1 User Registration** | Todo | Login is implemented but no resident sign-up UI or full registration/duplicate flow has been demonstrated |
| **F01.2 User Login & Logout** | Done | Flutter email/password sign-in, session gate, errors and sign-out are implemented and observed |
| **F01.3 Password Recovery** | Todo | No complete user-facing password-reset flow demonstrated |
| **F01.4 Role-Based Access Control (RBAC)** | In Progress | RLS and staff/admin checks verified; full admin role/user management not implemented |
| **F01.5 User Profile Management** | In Progress | Real profile read works, and backend permits own permitted columns; Flutter profile editing not demonstrated |
| **F02.1 Submit Maintenance Report** | Done | Form checks required fields and submits a `new` report to Supabase |
| **F02.2 Attach Photos to Reports** | Done | Preview, JPEG/PNG/WebP validation, max-size and report-linked private Storage upload exist; error feedback provided |
| **F02.3 Select Maintenance Category** | Done | Flutter loads only `is_active = true` categories; report is saved with matching active category ID |
| **F02.4 Validate Report Information** | In Progress | Required values, title `maxLength: 120` and photo constraints validated; description/location length rules not fully specified/enforced |
| **F03.1 View Submitted Reports** | In Progress | Staff queue and admin reports list implemented; staff screen shows category *ID* and does not visibly show creation date |
| **F03.2 Review Maintenance Reports** | Todo | Missing moderator-specific accept/duplicate/inappropriate workflow and persisted review outcome |
| **F03.3 Claim Available Reports (Staff Self-assignment)** | In Progress | Atomic backend RPC and Flutter claim interface operate; precise acceptance of claim timestamp representation (history vs dedicated timestamp), concurrency E2E and intended admin-web placement remain to confirm |
| **F03.4 Update Report Status** | In Progress | Claim/resolve status transitions and audit history timestamp implemented; dedicated staff web UI and visible update-time UX outstanding |
| **F03.5 Add Maintenance Notes** | Done | Flutter assigned-staff dialog creates and reads `report_notes`, captures `created_at`; verified RLS prevents resident access |
| **F04.1 View My Reports** | In Progress | Own-report filter, statuses, empty/loading/errors implemented; list omits submission date required by acceptance criteria |
| **F04.2 View Report Details and Track Progress** | In Progress | Own-report details and status implemented; details omit required submission date |
| **F05.1 Report Status Change Notifications** | Todo | Status-history logging is NOT resident notification delivery |
| **F05.2 Push Notification Delivery** | Todo | No verified token registration/delivery handling |
| **F06.1 Administrative Dashboard** | Done | Standalone HTML/JS admin UI shows real status counts and report navigation, gates `system_admin` role; the project team reports lecturer approval of this framework choice (21 Nov 2026) |
| **F06.2 User and Role Administration** | In Progress | Admin People & Roles view exists but is explicitly read-only; privileged edits missing |
| **F06.3 Maintenance Category Management** | Todo | Category schema and read-only category retrieval exist, but no admin create/edit/activate/deactivate UI or API workflow demonstrated |
| **F06.4 Report Search and Filtering** | In Progress | Admin supports text search and status filter; category/date filtering not demonstrated |

**Feature totals:** **6 Done**, **10 In Progress**, **6 Todo** (22 total).

## Implementation Task status (already adjusted manually on the lecturer's board)

| Status | Task names |
|---|---|
| Done (3) | Build resident maintenance report submission form; Implement report photo attachment in Flutter; Implement atomic staff self-assignment and report status transitions |
| In Progress (8) | Set up Flutter Mobile app structure and authentication screens; Build My Reports and report details screens; Design Supabase database schema for FixMate; Implement Supabase authentication profiles and role-based access; Implement maintenance report backend and image storage policies; Set up Flutter Web admin application and role-based navigation; Build available reports queue and staff claim interface; Build staff report status update interface |
| Todo (1) | Build moderator report review interface |

**Board totals assuming 40 existing items:** **9 Done**, **23 In Progress**, **8 Todo** = 3+6, 8+10+5, 1+6+1 respectively.

## Verification and board-update process

- Use [GitHub CLI Projects](https://cli.github.com/manual/gh_project_item-edit) to modify only the **Status field** of existing project items. `gh project item-edit <number> --owner ... --url <issue_url> --field "Status" --value "In Progress"` is the supported command form.
- Prefer the companion PowerShell script that **asks for the actual GitHub Project URL**, reads issue titles from the live board, previews changes, and only updates when run with `-Apply`.
- **Important:** the screenshots shared from the lecturer's board show the first implementation task as issue **#29**, whereas the student repo task starts at **#30**. The board may show a separate repository's issue numbers. This plan and the script match **titles and feature IDs**, not these potentially divergent numbers.
- Existing `main` does not yet include the three draft PRs; do not treat board Done as proof of a merged release or completion of all backlog features.
- A live board snapshot still needs to be read from the user's GitHub CLI login before committing status changes; the final counts are the **expected target**, not a claimed live result.

Related: [Lecturer review index](LECTURER_REVIEW_START_HERE.md), [Architecture](DATABASE_ARCHITECTURE.md), [Security QA](SECURITY_QA_VERIFICATION.md).
