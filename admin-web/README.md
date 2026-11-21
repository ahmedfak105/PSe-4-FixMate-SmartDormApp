# FixMate – Admin Web Dashboard (MVP)

This is the **standalone administrator web interface** for FixMate – SmartDormApp. It consists of `index.html`, `app.js` and `styles.css` and connects to the same Supabase backend as the Flutter resident/maintenance-staff application.

**Approved implementation choice (reported by the project team on 21 Nov 2026):** the lecturer has agreed to use a standalone HTML/CSS/JavaScript dashboard instead of the Flutter Web technology originally named in the backlog. This confirms the framework choice, **not** completion of every admin feature or security acceptance check.

## What the dashboard does

- Supabase connection setup with a **publishable / legacy anon key** and project URL.
- Email/password sign-in using existing Supabase Auth accounts: `system_admin` enters the Admin Dashboard; `maintenance_staff` is redirected to `staff.html` and `moderator` to `moderator.html`, each with a separate role guard.
- **Overview:** counts by report status and recent reports.
- **All reports:** report list, text search and status filter.
- **Assignments:** assign an eligible, unassigned new report to a maintenance staff account using the protected `assign_maintenance_report` RPC. Assignment retains the report's `new` status; maintenance staff then claim it in their Flutter interface.
- **People & Roles:** **read-only** listing of profiles and roles.
- **Maintenance staff web workspace (`staff.html`):** authorized staff can view available reports and their assigned jobs, claim with the protected RPC, resolve their own in-progress reports, and view submission/status-history timestamps where permitted by RLS.
- **Moderator review (`moderator.html`):** moderator/system_admin can review new unassigned reports with Valid, Duplicate or Inappropriate outcomes, inspect authorized private report photos and read persisted review decisions. **Requires the proposed SQL migration to be reviewed and deployed separately before this feature works.**

There is **no** admin user creation, direct role editing, category management, or general-purpose unrestricted SQL access in this MVP. Moderator review is coded but not yet operational until its proposed database migration is applied and end-to-end permission tests pass.

## Run locally

No Node.js build, package installation or bundling is required. Serve the `admin-web/` folder using a local HTTP server. Examples:

**VS Code Live Server:** open `admin-web/index.html` and use **Open with Live Server** (often `http://localhost:5500`).

**Python (if installed):**

```bash
cd admin-web
python -m http.server 5500
```

Then open `http://localhost:5500` in a browser. Python's command may be `python3` on some systems.

The HTML loads Supabase JavaScript SDK v2 via jsDelivr, so an internet connection is necessary. Avoid running this demo from a shared/public computer because browser storage contains the selected public connection configuration and user session.

## First-time connection and login

1. Supply the **HTTPS Supabase project URL**.
2. Supply the project's **publishable key** (`sb_publishable_...`) or legacy anon key. Never use `service_role` or `sb_secret_`.
3. Select **Connect to Supabase**.
4. Sign in using an existing **system_admin** test account (or **maintenance_staff** / **moderator** to open their role-specific pages).
5. Open **Overview**, **All reports**, **Assignments**, or **People & Roles**.

The current code persists the connection in browser `localStorage`. Use **Change Supabase connection** to replace it, or **Sign out** to end the current session.

## Backend requirements and security

The Supabase backend must already provide:
- Auth accounts with corresponding `public.profiles` entries and the correct `role` values.
- `public.maintenance_reports`, `public.maintenance_categories`, and `public.profiles` with appropriate SELECT grants and RLS.
- A restricted `assign_maintenance_report` function for authorized assignment.

The client-side role check is an interface safeguard, **not** the authoritative security boundary. RLS, grants, and server/database functions must deny inappropriate actions. Do not disable RLS to fix an access error.

The dashboard uses `supabase-js` rather than custom credentialed REST requests. When debugging, avoid hand-written `fetch` calls with `credentials: "include"` to a Supabase endpoint configured with wildcard CORS.

## Demo/testing notes

- Recorded browser evidence shows admin login, report lists and assignment views; prior workflow checks include successful assignment, staff claim and resolution with sample records.
- Manual browser tests are not a substitute for complete API permission/security tests across roles.
- Use demo accounts and sample reports; do **not** share passwords, bearer tokens or privileged keys with the lecturer.

## Repository status

This dashboard is currently developed on `feature/admin-web-dashboard` and reviewed through **PR #44**, separately from the Flutter app (PR #43) and database/documentation (PR #42). Review all branches and their acceptance criteria before merging into `main`.
