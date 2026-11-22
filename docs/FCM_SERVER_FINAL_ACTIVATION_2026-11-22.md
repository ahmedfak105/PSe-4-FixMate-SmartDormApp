# FixMate — final Firebase FCM activation and phone acceptance

**State on 22 November 2026:** Hosted Supabase `epsvagztisdovixlqehi` has
`report_notifications`, `push_device_tokens`, `push_delivery_outbox`, relevant
RLS/trigger/RPC and the server-side `send-report-push` Edge Function **deployed,
ACTIVE, version 1**, with `verify_jwt=false` for a **custom authenticated
server-to-server endpoint only**.

**This does NOT mean FCM push is delivering.** There is currently **no verified
private Firebase service-account secret**, no verified strong webhook secret,
no database webhook/cron invocation, and no independently captured Android
background notification success. The Edge function **fails closed**: its
`x-fixmate-push-secret` header must match a server-only secret of at least
32 characters before any delivery processing.

Deployment evidence: Supabase Edge function ID
`5845abb9-8798-4b12-8eb0-714bdc8551e9`, slug `send-report-push`,
status **ACTIVE**, version **1**; confirmed by listing and retrieving the
deployed source. Edge URL:
`https://epsvagztisdovixlqehi.supabase.co/functions/v1/send-report-push`.

## Operator setup (private — do not paste secrets into ChatGPT or GitHub)

1. In your own signed-in browser, open the existing
   [Firebase project](https://console.firebase.google.com/project/pse-4-fixmate-smartdormapp/settings/serviceaccounts/adminsdk).
   From **Project Settings → Service accounts** generate/download a dedicated
   Firebase service account private-key JSON. Confirm the account can send
   through **Firebase Cloud Messaging HTTP v1**, using only the necessary
   Firebase Cloud Messaging API Admin permissions. **Never commit the JSON.**
2. Open the existing [Supabase project](https://supabase.com/dashboard/project/epsvagztisdovixlqehi/functions)
   → **Edge Functions → Secrets**. Set these as *server-only* secrets:
   - `FIREBASE_SERVICE_ACCOUNT_JSON`: the complete private JSON text,
     including its project ID, client email and private key (paste privately
     into the secret-value UI).
   - `FIREBASE_PROJECT_ID`: `pse-4-fixmate-smartdormapp` (not secret).
   - `FIXMATE_PUSH_WEBHOOK_SECRET`: random 32+ character independent
     high-entropy value. Generate it on your own PC, not in GitHub.
3. One way to create a random secret privately on **Windows PowerShell**
   (the printed value is confidential and only belongs in Supabase secrets
   and trusted webhook/scheduler configuration):

   ```powershell
   $bytes = New-Object byte[] 48
   $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
   $rng.GetBytes($bytes)
   $rng.Dispose()
   [Convert]::ToBase64String($bytes)
   ```

   Do not post the output into chat, screenshots, version control or
   public Pages. `SUPABASE_URL` and the project's privileged default
   `SUPABASE_SECRET_KEYS` should be provided by trusted Supabase runtime;
   never paste those into an Android app or a website. If the runtime is not
   provisioning a privileged key, investigate privately rather than
   inventing one or copying a secret into source.
4. **Database Webhook**: from
   [Supabase Dashboard → Database → Webhooks](https://supabase.com/dashboard/project/epsvagztisdovixlqehi/database/hooks)
   create an **INSERT-only** webhook for `public.push_delivery_outbox`
   targeting the already deployed Edge Function.
   Set custom header **`x-fixmate-push-secret`** to the exact secret from
   step 2. Use the official [Database Webhooks guide](https://supabase.com/docs/guides/database/webhooks)
   for the current UI. Avoid adding a service-role key to client requests.
   **Caveat**: a Dashboard webhook may store the custom header in its SQL
   trigger definition, visible to privileged database administrators/dumps.
   If that is unacceptable, use a team-reviewed Vault-backed `pg_net`
   trigger instead, rather than storing the secret literal in a migration.
5. **Retry scheduler**: configure a trusted **every-5-minute**
   `pg_cron` + `pg_net` scheduled POST to the same function with the same
   header, reading the secret from **Supabase Vault** (do **not** embed the
   value as a literal in a public migration or a GitHub Action log). A
   webhook triggers immediate delivery; the scheduler retries transient
   failures after the backoff in the queue. See the official
   [Scheduling Edge Functions guide](https://supabase.com/docs/guides/functions/schedule-functions).
   Before enabling it, review Free-plan quotas. This step requires an
   operator who can set the private secret; it is intentionally **not
   preconfigured** without those credentials.
6. **Physical Android test**: install the connected APK. Log in as a
   dedicated Resident test account and enable the Android push preference.
   Allow notifications. Confirm an actual token is registered for that user
   without printing it. Change one of that Resident's reports to
   `in_progress` or `resolved` as Staff. Put Android in the background
   or lock the screen, then confirm the OS displays a FixMate alert with the
   correct report/status. Check that a second Resident receives nothing.
   Sign out/unregister and verify further updates do not send to that device.
7. Inspect the sender/outbox only through the private dashboard and
   authorized SQL; record aggregate statuses `sent/invalid/failed`, never
   raw device tokens or private credentials. If any test fails, keep GitHub
   Feature #24 and Release Gate #47 OPEN.

## Acceptance checklist

- [x] Flutter Firebase Android client + permission + Resident opt-in coded.
- [x] Hosted owner-scoped token registry, status notifications and private
      push queue installed with RLS.
- [x] Security-guard test suite / Deno sender typecheck passed in CI.
- [x] Server `send-report-push` function DEPLOYED (Supabase ACTIVE v1).
- [ ] Firebase service-account JSON set **privately**.
- [ ] Random webhook secret configured **privately** (server and caller).
- [ ] Database webhook invokes function for queued messages.
- [ ] Trusted retry scheduler with Vault secret configured.
- [ ] Background alert confirmed on one real Android phone; unauthorized
      cross-user delivery negative test passed.
- [ ] Lecturer/team accepts and closes Feature #24 and Release Gate #47.

**No paid resource, service-account creation, credential exposure or automatic
recurring invocation was performed by this handoff.** Do not claim 100% release
until the unchecked items are independently verified.
