# FixMate — F05.2 Android Push Delivery (Firebase FCM)

**Status: integration code prepared; remote delivery NOT activated or accepted.**
Feature [#24](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/24)
and [Release Gate #47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47)
must remain open until verified on hosted Supabase and a real phone.

## Existing confirmed Firebase setup

- Existing Firebase project: `pse-4-fixmate-smartdormapp` (number `677525069947`).
- Android application ID: `lt.kaunokolegija.vp_mobile`, matches the Firebase project registration and `mobile/android/app/build.gradle.kts`.
- The project owner provided the **Android client** config `google-services.json`; it is in `mobile/android/app/google-services.json` on the integration branch. Do not confuse this non-secret client config with a **service account JSON**, which must never be committed or pasted into chat.
- Android Google services Gradle plugin, pinned FlutterFire Core/Messaging dependencies, and Android notification permission are prepared.
- `mobile/lib/features/notifications/fixmate_push_service.dart` implements Android-only Resident opt-in, token refresh, owner-scoped registration and best-effort token deletion before logout.
- `mobile/lib/features/settings/profile_page.dart` presents an English/Lithuanian push preference. This is a **registration preference**, not proof of remote delivery.

## Server implementation staged locally

- `supabase/migrations/20261122194500_report_notifications.sql` records in-app status-change notifications for the report owner.
- `supabase/migrations/20261122210500_fcm_device_tokens.sql` creates an RLS-protected device-token registry with no access for non-owners.
- `supabase/migrations/20261122234000_fcm_push_delivery_outbox.sql` queues notification deliveries transactionally for the report owner's registered Android devices, handles token revocation and offers atomic, service-role-only claims with retry leases. Client roles cannot SELECT the outbox or call the claim RPC.
- `supabase/functions/send-report-push/index.ts` is a **server-only** FCM HTTP v1 dispatcher. It accepts POST requests carrying an independent high-entropy webhook secret, validates the Firebase project ID, signs a short-lived OAuth 2 assertion using WebCrypto, sends only queued report/status data to the stored owner token, and retries transient errors. It never returns tokens or privileged credentials to a browser.
- `docs/sql/test/local_supabase_api_smoke.sh` checks owner-only token registration, denied role abuse, durable queue creation, denied client claims and cancellation on revoke **against disposable local Supabase**.

**No server migration, service-account secret, webhook or sender has been deployed to populated hosted Supabase.** The outbox is at-least-once: rare duplicate delivery may occur after worker/network crashes. Do not promise exactly-once remote delivery.

## Controlled rollout — only after #47 release approval

1. Review all additive-only migrations against the **actual hosted schema** (migration history may differ from existing database objects). Make and **verify** a recoverable backup; never run `db reset` or replay the baseline on live data.
2. Apply only approved migrations, and verify every RLS policy using **real authenticated Resident/Staff/Admin** sessions.
3. In the existing Supabase project, store the following in **Edge Function secrets**, not code/GitHub/chat:
   - `FIREBASE_SERVICE_ACCOUNT_JSON` — a dedicated Firebase service-account JSON limited to the necessary **Firebase Cloud Messaging API Admin** permissions.
   - `FIREBASE_PROJECT_ID=pse-4-fixmate-smartdormapp`.
   - `FIXMATE_PUSH_WEBHOOK_SECRET` — a randomly generated 32+ character secret; never display this publicly.
   - `SUPABASE_URL` and `SUPABASE_SECRET_KEYS` are supplied by the trusted Supabase runtime (current named `default` `sb_secret_` API key). Older *disposable local* runtimes may still inject the legacy `SUPABASE_SERVICE_ROLE_KEY`. Never put either privileged key in Flutter, GitHub, a browser, or the Database Webhook header.
4. Deploy `supabase/functions/send-report-push` with **`verify_jwt=false` only for this server-to-server endpoint**. Its own `x-fixmate-push-secret` check is mandatory. All other functions must keep their existing authorization.
5. Configure a **Database Webhook** on INSERT to `public.push_delivery_outbox` calling the Edge Function with the same secret header. The function claims jobs from the queue rather than trusting any arbitrary recipient ID in the webhook payload. Add a low-frequency trusted scheduler for retries after observing free-tier quotas; a webhook alone cannot retry delayed failed sends. Limit scheduled invocations and disable if usage approaches any paid threshold.
6. Test with a **controlled Resident Android phone**, a second Resident, and Maintenance Staff: opt in, change status, confirm Android receives the expected alert while backgrounded, confirm role isolation and no cross-account delivery, revoke token/sign out and confirm no further sends.
7. Only then close Feature #24 and #47 following lecturer/team approval.

Reference: [Supabase FCM Edge Function guide](https://supabase.com/docs/guides/functions/examples/push-notifications?platform=fcm), [FCM HTTP v1](https://firebase.google.com/docs/cloud-messaging/send/v1-api), and [Supabase function secrets](https://supabase.com/docs/guides/functions/secrets).

## $300 promotional credit: billing caveat

The owner stated that the project's linked Google Cloud billing account has a **$300 promotional credit**. Firebase Console shows the project on **Blaze**, which is expected for a Firebase project linked to a Google Cloud billing account. This does **not** mean every cloud feature is permanently free.

- Google's common new-customer $300 Free Trial lasts **90 days from trial signup** and ends sooner if credit is exhausted. On a **Free Trial billing account**, Google says users are not billed during the trial; if converted to a **Paid billing account**, charges may occur outside the remaining credit and after expiry.
- **Do not assume** the entire $300 balance remains or know its expiry date without checking the billing console. Google offers other promotional credits with different terms.
- **FCM itself has no sending fee**. The planned sender uses the already connected Supabase project's Edge Function allowance, which has independent quotas and possible charges. No Firebase Cloud Functions, Google Cloud Run, BigQuery export or paid add-ons are required.
- Before any billable deployment, check the exact remaining credit, expiry, billing account state and applicable quotas; set a low [Google Cloud budget alert](https://console.cloud.google.com/billing). Budget notifications alone do **not** cap spending.
- **No change to billing, Firebase Blaze plan, credit balance, hosting, account roles or live Supabase deployment was made.**

Official references: [Google Cloud Free Trial](https://cloud.google.com/free/docs/free-cloud-features), [Firebase billing plans](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans), [FCM no-cost product](https://firebase.google.com/products/cloud-messaging).

## Acceptance checklist

- [x] Firebase project and Android package matched; client config added.
- [x] Android FCM opt-in code, device registry and server-side outbox prepared.
- [x] Server-side FCM HTTP v1 sender source prepared (not deployed).
- [ ] Exact final revision passes Flutter CI, Android build, local RLS/API tests and real Chrome E2E.
- [ ] Hosted Supabase backup/recovery and additive migration approval (#47).
- [ ] Sender secrets stored and database webhook/scheduled retry configured by authorized operator.
- [ ] Real Android background-delivery test completed; no sends to non-owner.
- [ ] Feature #24 marked Done only after all acceptance requirements pass.


## November 2026 Supabase key compatibility and sender tests

- PR #48 prepares the server for Supabase's **new secret API keys**: it selects `SUPABASE_SECRET_KEYS.default` when present, sends `sb_secret_...` **only** in the `apikey` header, and never sends an opaque key as an `Authorization: Bearer` JWT. An existing legacy `service_role` JWT remains a fallback **only** when the new secret-key dictionary is absent (local CLI compatibility). Malformed/missing privileged keys fail closed. This is a code-only proposal, not a live rotation.
- The extra no-network Node 22 guard tests check webhook authentication, typed FCM `UNREGISTERED`, new/legacy privileged header rules, and malformed server configuration. Workflow: `.github/workflows/fcm-sender-guard-tests.yml`.
- Supabase's privileged `claim_fixmate_push_jobs` RPC retains server-role-only `EXECUTE` and a separate role check. **Before switching hosted credentials**, explicitly verify an atomic claim with the project's actual new `sb_secret_` key in an approved isolated environment. The two key formats and gateway role context must be tested end-to-end; helper tests alone cannot prove live Data API authorization.
- Never put a Supabase secret key or Firebase service-account JSON into the phone app, GitHub Actions logs, screenshots, or chat. The webhook authenticates to the dispatcher with its own independent high-entropy `x-fixmate-push-secret` header; that secret must be stored securely in the approved backend/webhook configuration.
- After any successful FCM end-to-end device test, test a second resident and sign-out/revocation. Do not close #24 or #47 merely because unit tests or backend builds passed.

Sources: [Supabase key migration](https://supabase.com/docs/guides/getting-started/migrating-to-new-api-keys), [Supabase Edge secrets](https://supabase.com/docs/guides/functions/secrets), [FCM error codes](https://firebase.google.com/docs/cloud-messaging/error-codes).
