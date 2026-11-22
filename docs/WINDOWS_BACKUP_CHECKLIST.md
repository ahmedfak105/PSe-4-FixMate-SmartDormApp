# FixMate — Windows backup checklist before hosted Supabase rollout

**For the existing live project** `epsvagztisdovixlqehi` on the confirmed **Free** plan. This is a safe operator checklist — **not** approval to run SQL migrations on the populated project.

## What we can and cannot automate

- A new local PowerShell helper [`scripts/backup_fixmate_windows.ps1`](../scripts/backup_fixmate_windows.ps1) exports separate SQL files with the official Supabase CLI `db dump` commands. It requires the **operator's own Windows PC**, a working Docker Desktop, a compatible Supabase CLI, and a database password entered locally. Do not send a password or a complete DB URL in chat.
- The helper is **read-only on the hosted project**. It does not alter Auth accounts, reports, Storage, policies or migrations. It validates the file sizes and hashes, but **does not test a restore**.
- Storage object *bytes* must be saved separately. The live `report-photos` private bucket had **2 objects (about 962 KB of declared metadata size)** at a read-only audit on 2026-11-22. Object count can change; recheck it on the day of backup.
- Both the dump and all private photo files contain potentially personal data. Use a private, encrypted folder **outside OneDrive/GitHub/Google Drive/chat**.

## A. Backup SQL on Windows

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and the [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started); start Docker. Run `supabase db dump --help` and confirm the documented flags. No paid Supabase plan is needed.
2. Download or clone the **integration** repository branch. Open PowerShell **in the repository root** (next to the `scripts` directory).
3. In a private browser session open [Supabase Dashboard → Connect](https://supabase.com/dashboard/project/epsvagztisdovixlqehi?showConnect=true). Choose **Session Pooler**. Copy the Postgres connection URI but leave the password as literal `[YOUR-PASSWORD]`.
4. Run this command locally; use your own chosen encrypted directory if available:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\backup_fixmate_windows.ps1
   ```

   This bypasses PowerShell script restrictions **for this single process**, not system-wide. Review the script before running. It verifies Docker and CLI, refuses an incorrect project ID, asks for the actual password **hidden**, and writes into `$HOME\FixMateSecureBackups\FixMate-<UTC timestamp>-<random id>\`. An operator can instead use `-OutputRoot 'D:\FixMateSecureBackups'`.

5. After success, confirm `roles.sql`, `schema.sql`, `data.sql`, `CHECKSUMS.json` all exist. The hashes show the files were not accidentally modified. **The manifest deliberately says `FILES_CREATED_NOT_RESTORE_TESTED` and `private_storage: NOT_EXPORTED`.**
6. Keep this directory encrypted. Do not commit it, attach it to an issue or share SQL files. If any command fails, **do not deploy** the remaining migrations.

Official guide: [Backup and Restore using the CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore). The CLI uses Docker and works with the private DB connection. The project is Postgres **17**.

## B. Back up the private report photos (separate step)

With a trusted authorized Supabase project dashboard session:

1. Open [Storage → report-photos](https://supabase.com/dashboard/project/epsvagztisdovixlqehi/storage/buckets).
2. Download **each** object into a private `storage-report-photos` backup folder. Preserve its original relative path and filename. At the time of last audit there were **2 files**; confirm the latest bucket count and file sizes rather than assuming it is still two.
3. For many objects, Supabase supports S3 tools such as Cyberduck or AWS CLI under [Storage S3 settings](https://supabase.com/dashboard/project/epsvagztisdovixlqehi/storage/s3), but S3 access keys **bypass RLS** and must stay only on the operator's trusted computer. Do not use S3 keys in Flutter, the browser app, a public URL or CI. For two files, manual dashboard download is simpler.
4. Check that the actual downloaded **bytes** open and match the object inventory; a database `storage.objects` record is only metadata and cannot reconstruct a photo.

Official docs: [Download objects](https://supabase.com/docs/guides/storage/management/download-objects), [S3 authentication](https://supabase.com/docs/guides/storage/s3/authentication).

## C. Prove recovery without risking production

1. Create/use an **isolated local** Postgres/Supabase environment, ideally **Postgres 17**. Follow the official [restore guide](https://supabase.com/docs/guides/self-hosting/restore-from-platform); do not restore to the hosted FixMate project.
2. Restore the dumped roles/schema/data into that empty isolated target with the official sequencing; reconcile differences in managed Auth/Storage schemas if needed. Verify actual Auth users/profiles and existing report row counts, triggers, role privileges and RLS, with no personal data exposed.
3. Restore/download at least the protected photo objects as **files**, confirm checksums and the expected count.
4. Record only the date, filenames (not file contents), aggregate row/object counts and **restore test success** in GitHub issue [#47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47). If restoration is untested or fails, deployment remains blocked.

## D. After the operator reports a successful backup and restoration

Then the team/lecturer can review the **additive-only** migrations already in `supabase/migrations/`, without replaying the populated database baseline or resetting it. Test one role at a time (Resident, Staff, Moderator, Admin), avatar ownership, notifications, token isolation, and Firebase sending on a physical Android phone.

**Status:** Script prepared, **real SQL backup pending**, **private photos backup pending**, **isolated restore rehearsal pending**, **migration approval pending**. Green GitHub CI and a user's successful basic report test are **not** a substitute for a recoverable backup.
