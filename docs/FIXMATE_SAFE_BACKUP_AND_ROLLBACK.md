# FixMate — secure manual backup / restore rehearsal gate (Free plan)

**Purpose:** protect the *existing* hosted Supabase project `epsvagztisdovixlqehi` before any approved additive migrations. On 22 Nov 2026, the Supabase organization was confirmed on **Free**, which does not include daily automatic project backups. An SQL dump is **not** enough to preserve the bytes of private `report-photos` Storage objects.

**Important:** These steps must run on a trusted operator computer with sufficient encrypted local storage and Docker/Postgres tooling. They have **not** been performed or verified by ChatGPT against the real project, because no private database connection or recoverable backup was available. Never paste passwords, full connection URLs, backup files, Auth users, hashed passwords, service-role keys, or Firebase service-account JSON into GitHub issues, chats, screenshots, or CI logs.

## 1. Review and prepare

- Confirm this is the correct project and its current data. An existing [read-only release audit](sql/FIXMATE_HOSTED_RELEASE_AUDIT_READ_ONLY.sql) checks table presence, RLS and grants without retrieving names/emails/reports.
- Open [Supabase Dashboard → Project → Connect](https://supabase.com/dashboard/project/epsvagztisdovixlqehi) in your own authenticated browser. Copy the **Session Pooler** Postgres connection URL and use the database password. Be careful with special characters in the URL password (percent-encode as required). Do not confuse it with a public publishable key.
- Install current [Supabase CLI](https://supabase.com/docs/reference/cli/introduction) plus Docker/PostgreSQL tools, and check `supabase db dump --help` on your installed version; flags may change.
- Make a private output directory on encrypted storage. Do not work inside a synced or public Git repository.

## 2. Export the existing hosted database locally

The commands below follow [Supabase's official CLI backup guide](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore). Run in a trusted shell; the password stays local.

```bash
umask 077
mkdir -p "$HOME/fixmate-secure-backups"
cd "$HOME/fixmate-secure-backups"

# Prompt without echoing into terminal or shell history.
read -r -s -p "Private Supabase Postgres connection URL: " FIXMATE_DB_URL
printf '\n'
export FIXMATE_DB_URL

supabase db dump --db-url "$FIXMATE_DB_URL" -f roles.sql --role-only
supabase db dump --db-url "$FIXMATE_DB_URL" -f schema.sql
supabase db dump --db-url "$FIXMATE_DB_URL" -f data.sql --use-copy --data-only \
  -x "storage.buckets_vectors" -x "storage.vector_indexes"

test -s schema.sql && test -s data.sql
sha256sum roles.sql schema.sql data.sql > SHA256SUMS.txt
unset FIXMATE_DB_URL
```

*This is an operator runbook; no command in this document has been executed on the live project.* The dumps may include **sensitive Auth data** and must be encrypted, kept outside source control, and accessible only to authorized team members. Record their file sizes/checksums privately; do not include backup bytes or the database connection URL in issue #47.

## 3. Save private Storage files separately

- The live bucket `report-photos` is **private** and has a 5 MiB image limit. Download/export every object and preserve the relative `storage_path`, MIME type and bucket association using an authorized account/backend under normal privacy rules.
- Compare the exported object inventory to `storage.objects` metadata. The database dump alone captures at most metadata; **it will not back up Storage object contents**.
- See the [Supabase Storage download guide](https://supabase.com/docs/guides/storage/management/download-objects) for a trusted S3-compatible export workflow.
- Do not create a public bucket, or grant broad SELECT on private files, just to make backups easier.

## 4. Prove that a restore works

- Restore into an **isolated** trusted local test instance (recommended for no-cost evaluation) or an already approved staging resource. Do not use the original live project as the restore target. Supabase's [restoration guide](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore) documents safe sequencing and Auth/Storage-specific considerations.
- Verify schema, table data row counts, existing `auth.users` and `profiles` references, role grants, RLS and trigger/function inventories without displaying personal data.
- Confirm previously stored photos can be recovered as **files**, not just `storage.objects` rows.
- Record when the dump was made, checksum match, test-environment details and **successful restore evidence**. Only record metadata/evidence in the release issue; keep all credentials and restored personal data private.
- If the rehearsal fails, fix the backup process and repeat. **Do not continue to hosted SQL rollout on an unverified backup.**

## 5. Continue through Issue #47 only after approval

After team/lecturer sign-off, compare the hosted schema against the ordered, additive source migrations and reconcile empty Supabase migration history; do not replay the fresh baseline and do not run `supabase db reset` on production. Apply only reviewed changes with a recoverable rollback plan, test four roles and rerun Supabase advisors. Then separately configure FCM sender secrets, push webhook and real Android-device delivery.

**References:** [Database backups](https://supabase.com/docs/guides/platform/backups); [CLI dump / restore](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore); [Storage objects download](https://supabase.com/docs/guides/storage/management/download-objects).
