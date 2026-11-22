# FixMate — enable real Android Firebase notifications

**Verified hosted status on 22 November 2026**

- Supabase project: `epsvagztisdovixlqehi` (Free plan).
- **FCM Edge sender deployed:** `send-report-push` is ACTIVE version 1.
- **Database push queue and user-only token RLS:** deployed.
- **Automatic dispatch:** now INSTALLED. `pg_net` and `pg_cron` are enabled.
  The new `fixmate_push_send_on_queue_insert` trigger dispatches promptly
  when an eligible queue item is inserted; `fixmate_push_vault_dispatch`
  polls for retries every five minutes using a private database function.
- **Strict safety:** there is currently **no** `fixmate_push_webhook_secret`
  saved in database Vault (confirmed by count only). Without it, both
  the trigger and cron return immediately and **never send an HTTP request**.
  The Edge sender also denies requests without its own strong
  `FIXMATE_PUSH_WEBHOOK_SECRET`. No Firebase private JSON was installed by
  ChatGPT (no credential-setting capability), and no background phone push
  was independently observed.
- **Current test inventory:** zero registered Android FCM devices and zero
  pending jobs at this read-only checkpoint. A signed-in Android Resident
  must opt in specifically to notifications.
- **Schema history:** hosted migration `20261122170759`,
  `fixmate_push_vault_bridge_live`; archived verbatim in
  [`docs/sql/FCM_LIVE_VAULT_BRIDGE_APPLIED.sql`](sql/FCM_LIVE_VAULT_BRIDGE_APPLIED.sql).
  Do not replay it or blindly run `supabase db push` against live data.

## Only remaining private operator setup

Open the **existing** Firebase and Supabase accounts in your own browser.
**Do not attach any key, JSON, database URL or screenshot showing secrets to
ChatGPT, GitHub, an email or a public document.**

### A. Firebase credentials → Supabase Edge secrets

1. In [Firebase Console → Project Settings → Service Accounts](https://console.firebase.google.com/project/pse-4-fixmate-smartdormapp/settings/serviceaccounts/adminsdk),
   choose **Generate new private key** under Firebase Admin SDK.
   Keep the downloaded JSON file **private on your computer**.
   Use a dedicated service identity with only necessary FCM message-sending
   permissions where your IAM access permits it; do not commit this file.
2. In [Supabase → Edge Function secrets](https://supabase.com/dashboard/project/epsvagztisdovixlqehi/functions/secrets),
   add these keys:
   - `FIREBASE_SERVICE_ACCOUNT_JSON` = **the full content** of the
     downloaded JSON file, private.
   - `FIREBASE_PROJECT_ID` = `pse-4-fixmate-smartdormapp` (not secret).
   You do **not** need to redeploy the function after setting secrets.
3. Generate a **separate** high-entropy webhook secret, 48 random bytes
   Base64-encoded. Windows PowerShell example (run locally; do not share
   the output):

   ```powershell
   $random = New-Object byte[] 48
   $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
   $rng.GetBytes($random)
   $rng.Dispose()
   [Convert]::ToBase64String($random)
   ```

   Add it in Supabase **Edge Function secrets** with key
   `FIXMATE_PUSH_WEBHOOK_SECRET`.

### B. Store the *same* webhook secret in Database Vault

In the same Supabase project, open **Database → Vault** (the encrypted
secrets UI, distinct from Edge Function secrets). Create one secret:

| Field | Exact value |
| --- | --- |
| Name | `fixmate_push_webhook_secret` |
| Secret value | **Exactly the same** private random string used for `FIXMATE_PUSH_WEBHOOK_SECRET` |
| Description | `FixMate server-only FCM queue dispatcher` |

**Save privately in Vault's UI**, not in a committed migration, Dashboard SQL
Editor history, screenshots or chat. Once this named secret is present,
the existing trigger and five-minute scheduler are already configured to
invoke the Edge sender only when a pending/retryable queue job exists. **Do
not create another Database Webhook** for the same outbox; it would duplicate
requests. Existing Vault's encrypted storage is used only by a restricted
`fixmate_private` function, never a public RPC.

### C. Test on a real Android phone

1. Install/open the **connected Android APK**, not just Flutter Web.
   Sign in as a dedicated test **Resident**.
2. Open **Profile → Enable notifications** and accept Android permission.
   The user/device token should appear in `push_device_tokens` for that
   owner. Never display the token publicly.
3. Prepare a report owned by this Resident. As **Maintenance Staff**,
   claim and change its status to `in_progress` or `resolved`.
   The status-change trigger creates the owner's in-app notification and
   an FCM job for subscribed devices.
4. **Lock the Android screen or background the app.** Verify an operating
   system FixMate notification with the correct report/status appears.
   Verify **Resident B** receives nothing for Resident A's report.
5. Sign out or turn off notifications, repeat a status change and verify
   there is no further alert to the revoked token.
6. Record test success/time/device (non-sensitive metadata only) in
   [Feature #24](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/24)
   and [Release Gate #47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47).
   Do not claim completion merely because the DB queue is empty; verify
   actual phone delivery.

The sender retries on transient failures and can deliver the same message
twice in rare network-failure scenarios. Keep personal data and keys out
of sender logs and client apps.

## Troubleshooting / safe pause

- If phone registration fails, check Firebase Google Play Services,
  Android notification permission, and the Resident opt-in control.
- If no outbox row is generated, confirm the token was registered **before**
  the report's status changed. Earlier status updates do not backfill push.
- If outbox remains pending, check **Edge Function invocation logs** and
  **private** `cron.job_run_details`. Do not paste raw tokens or secrets.
- To pause automatic retries (operator-only SQL):
  `SELECT cron.unschedule('fixmate_push_vault_dispatch');`
  The sender can also be disabled by removing the named Vault secret.
- The bridge is designed not to interfere with status updates when FCM is
  unavailable. `pg_net` temporarily keeps outbound header values in its
  privileged request queue; treat admin SQL access as sensitive.

**Accepted:** existing app core functionality, 11 public RLS tables, in-app
notifications, reviewed FCM server code, ACTIVE Edge v1, private Vault
dispatch trigger and cron with no-secret fail-closed behavior, rollback-only
database smoke tests.

**Still open:** three Edge secret values configured by an authorized owner,
the matching named Vault secret, actual Resident FCM registration and real
background Android delivery, and lecturer/team final sign-off. No paid
resources were purchased or project plan changed.

**References:** [Supabase Edge secrets](https://supabase.com/docs/guides/functions/secrets),
[Vault](https://supabase.com/docs/guides/database/vault),
[Cron scheduling](https://supabase.com/docs/guides/functions/schedule-functions),
[Firebase Admin service account](https://firebase.google.com/docs/admin/setup).
