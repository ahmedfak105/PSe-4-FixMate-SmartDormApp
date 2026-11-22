# FixMate — Local Role-Based Demo (No Hosted Database Changes)

**Audience:** Lecturer and FixMate 3-person team.  
**Last verified automation:** Integrated Flutter Web Chromium E2E and local Supabase role/Storage API tests, November 2026.  
**Purpose:** Reproduce Admin, Moderator, Maintenance Staff and Resident workflows safely without using live dormitory records.

## What this demo does

It uses **Supabase CLI and Docker on your laptop**, not a cloud staging project. A fresh local PostgreSQL/Supabase instance is reconstructed from the three committed `supabase/migrations/` files and then enhanced with proposed report input validation and Moderator review SQL. Five fictional Auth users, private photo fixtures and sample reports are created by the same local-only API smoke tests used in GitHub Actions. This is a real local database and Auth API — not a UI-only fake.

**Important:** The script runs `supabase db reset` and destroys **only the local CLI database**. It refuses pre-existing external PostgreSQL host settings or a nonlocal Supabase API. Never run the script in an environment where your actual data lives in the local Supabase instance. Back up any existing local development records first.

## Preparation on a laptop

Required: Docker (running), Git, Supabase CLI, PostgreSQL's `psql`, `curl`, `jq`, and Flutter stable with Chrome. A laptop is needed for this local stack; the Android phone alone cannot run Docker/Supabase CLI conveniently.

Open the [integrated repository](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/tree/integration/lecturer-review-2026-11-22) and check out its integration branch:

```bash
git clone https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp.git
cd PSe-4-FixMate-SmartDormApp
git switch integration/lecturer-review-2026-11-22
bash -n scripts/prepare_local_lecturer_demo.sh
bash scripts/prepare_local_lecturer_demo.sh
```

The bootstrap will download/start local Supabase images as needed, reset the local database, apply **only to that local instance** [the validation proposal](sql/PROPOSED_REPORT_INPUT_VALIDATION.sql) and [Moderator review proposal](sql/PROPOSED_MODERATOR_REVIEW_MIGRATION.sql), seed five local accounts and exercise Auth/RLS/REST/Storage permissions.

If any step errors, **stop** rather than bypassing the local URL checks or granting broader permissions. Review the command output and Docker status.

## Sample accounts

All emails below exist **only in this newly generated local database**. The example password is defined in `docs/sql/test/local_supabase_api_smoke.sh` and must never be used for any real account.

| Role | Local email |
|---|---|
| Resident A | `resident.a.fixmate@example.com` |
| Resident B | `resident.b.fixmate@example.com` |
| Maintenance Staff | `staff.fixmate@example.com` |
| Moderator | `moderator.fixmate@example.com` |
| System Admin | `admin.fixmate@example.com` |

Use separate Chrome profiles or sign out between roles. The accounts are **synthetic**, and profiles are promoted by the trusted test operator after signup. Normal residents cannot choose Moderator/Admin role.

## Start the Flutter Web Operations interface

In another terminal on the same laptop:

```bash
cd mobile
flutter pub get
flutter gen-l10n
flutter run -d chrome --dart-define=FIXMATE_OPERATIONS_WEB=true
```

On the public connection screen enter **Supabase URL** `http://127.0.0.1:54321` and the **local ANON_KEY** shown by running `supabase status -o env` from the repository root. The anon key is a public key; never paste `SERVICE_ROLE_KEY`, `sb_secret_` keys, a database password or personal tokens into the browser.

Log in with the fictional Admin, Staff or Moderator account.

## Start the Resident application on the same laptop

In a separate Flutter run (not the operations-only mode), using the local anon key:

```bash
cd mobile
flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_LOCAL_ANON_KEY
```

A desktop Chrome session on this computer can access `127.0.0.1`. A physical Android phone cannot use the computer's `127.0.0.1` — it points to the phone itself. For a physical phone demo, configure a reachable **approved** staging URL and test the network setup separately; do not open database ports publicly without proper security.

## Recommended 7-minute workflow

1. **Resident A:** open My Reports, submit a new test issue under Plumbing, confirm the report appears. Attach a synthetic image if you want to demonstrate private Storage.
2. **System Admin (Flutter Web):** inspect the live local dashboard, report status totals, search and People directory. Assign a separate eligible New report to Staff; assignment leaves it New.
3. **Staff (Flutter Web):** view Available / My Jobs, claim the assigned report, add notes and resolve it. Show status history / update time.
4. **Moderator (Flutter Web):** select an unassigned New report, view a private test photo and save a Duplicate or Inappropriate decision with a reason. A rejected report cannot be claimed.
5. **Resident B:** demonstrate denied access to Resident A's report and photo, and denied entry to the privileged operations web interface.
6. **Architecture:** show [original six-table ERD](FIXMATE_ERD.md), [proposed Moderator ERD](erd/FIXMATE_PROPOSED_MODERATOR_ERD.mmd), SQL JOINs and RLS queries from [read-only example SQL](sql/FIXMATE_DEMO_QUERIES_READ_ONLY.sql).
7. **CI evidence:** show [integrated release build](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44963696769) and [Flutter Web Chrome tests](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44963696839).

Do not describe the local Moderator migration as deployed to the hosted project. The original remote schema is still six tables; the local demo has the proposed seventh.

## Finish or restart

```bash
supabase stop --no-backup
```

Next time you re-run the bootstrap it recreates these same synthetic users and data in a **fresh local database**. The steps do not change `main` on GitHub or any hosted Supabase project.

## When this is not enough

This local demonstration proves the tested app flows and SQL on Supabase CLI, but **not** a deployed, shareable public website, a production Auth-email configuration, or a live Moderator user in the existing hosted project. Closing Tasks [#36](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/36) and [#39](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/39) requires the reviewed staging/target-project acceptance defined in [the controlled rollout guide](CONTROLLED_SUPABASE_ROLLOUT_TASK36_TASK39.md). There is no separate staging Supabase project/branch connected to this account at the last inspection.
