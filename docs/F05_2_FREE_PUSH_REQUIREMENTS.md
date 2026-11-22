# FixMate — free push-notification delivery plan (F05.2)

**Status: not live / not accepted.** Do not label F05.2 Done merely because F05.1 in-app notifications are locally implemented.

## Selected free option

- **Firebase Cloud Messaging (FCM)** for Android push: Google lists messaging as a no-cost product. https://firebase.google.com/products/cloud-messaging
- **Existing Supabase Edge Functions** can run a trusted server-side sender within the current project's free-tier quota. https://supabase.com/docs/guides/functions/pricing
- No Firebase paid Functions, external notification subscriptions, paid Supabase branch, or billing activation are required for this design.

## One-time project-owner inputs

The connected GitHub and Supabase integrations cannot create or configure a Firebase project/device directly. A project owner must:

1. Create a **Firebase Spark (no-cost)** project named **FixMate** and register the Android app using this exact, case-sensitive package ID: `lt.kaunokolegija.vp_mobile` (verified from `mobile/android/app/build.gradle.kts` on the integration branch). **Do not use** the separate password-recovery callback URI `com.fixmate.smartdorm://reset-password`. If Firebase requests a display nickname, use `FixMate Android`.
2. Download the app's Firebase client configuration `google-services.json` after registration. Its eventual Android path is `mobile/android/app/google-services.json`. You can provide the file to the project workflow through an authorized connection or a controlled upload; do not paste private keys into chat. **Do not** confuse it with any Firebase service-account JSON, which is a server secret and must never go in the browser, mobile bundle or GitHub repository.
3. Approve configuring FCM sender credentials as **Supabase Function secrets** on the existing project, and authorize the relevant additive-only backend migration under release gate #47.
4. Provide a test Android phone/account for a real foreground/background delivery acceptance test.

## Required implementation before F05.2 can be called Done

- [ ] Add `firebase_core` / `firebase_messaging` using reviewed pinned versions; request notification permission and initialize Firebase only in the configured Android build.
- [ ] Register/rotate/revoke device tokens through authenticated owner-only Supabase RLS; sign-out must revoke ownership. No device token may be attached to another resident's account.
- [ ] Make an idempotent server-side outbox derived from F05.1 status notifications. Target only `resident_id`, never arbitrary request-selected recipients.
- [ ] Send via FCM HTTP v1 from a trusted Supabase Edge Function; keep all private keys in environment secrets.
- [ ] Retry transient delivery failures, mark invalid tokens inactive, and keep report-status mutations independent of any push network failure.
- [ ] Run free local security tests plus a real Android handset test: delivery when app is backgrounded/closed, correct report/status, cross-account isolation, no duplicate delivery, no rollbacks on FCM failure.
- [ ] Only then update Feature #24 to Closed/Done and deploy after #47.

**Existing user-visible behavior:** F05.1 provides a private in-app notification inbox in the local implementation. It is not a substitute for a delivered push notification.

## Security and costs

Never use client-facing publishable keys as FCM sender secrets. Never place service-account JSON in Dart, the web bundle, or source control. Use Firebase Spark and existing no-cost tiers; stop if quotas or pricing would create charges.


## Verification at next continuation

- [x] Exact Gradle `applicationId` independently checked: `lt.kaunokolegija.vp_mobile`.
- [x] Free FCM/Spark setup instructions checked against official Firebase Flutter/Android setup guidance.
- [ ] Firebase ChatGPT plugin installed/connected (plugin discovery currently reports installed=false); this requires explicit user action.
- [ ] Firebase Spark project created and Android app registered with matching package.
- [ ] Config retrieved, Gradle/FlutterFire integration reviewed and tested in a disposable release build.
- [ ] Server sender credentials stored only in approved private secrets and end-to-end delivery tested before claiming F05.2 Done.

Free setup references: https://firebase.google.com/docs/android/setup and https://firebase.google.com/docs/flutter/setup .
