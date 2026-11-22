# FixMate F05.2 — Verified Android locked-screen Push Acceptance

**Date:** 22 November 2026  
**Feature:** [#24 F05.2 Push Notification Delivery](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/24) — **Closed / Completed**  
**Product-release gate:** [#47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47) — **still Open** pending team/lecturer approval and final release review

## Proven real-world delivery

One real Android phone registered an FCM device token under an authenticated
Resident account using the application's explicit Profile opt-in and Android
notification permission. The registration was verified by read-only
Supabase query without displaying its token.

A single controlled test inserted **in-app notification #3** for an already
resolved **report #11** belonging to that Resident. The existing report
status was **not modified**. The record inserted by the server-only outbox
trigger led to **push_delivery_outbox job #2**. Hosted evidence:

- Supabase outbound webhook HTTP response: **200**.
- Job #2 outcome: `sent` after **1** attempt; `last_error` was null;
  `sent_at` = **2026-11-22T17:55:28.673Z**.
- Exactly **one** real Android push device was registered at test time.
- The owner confirmed receiving the alert by saying **“وصلت”**
  (“It arrived”) and, when asked about the device state, replied
  **“مقفولة”** (“The screen was locked”). This is a user-reported
  physical-device acceptance test, not a fabricated video recording.

## Privacy / isolation

A second, synthetic Resident token was temporarily inserted inside a
**fully rolled-back SQL transaction**. Enqueueing a notification for the
real Resident created exactly **one job for the intended Resident** and
**zero jobs for the second Resident**. After rollback, no synthetic token
or notification remained. Earlier API/RLS checks also verified client
denial and owner-scoped token registration and revocation.

The FCM server code uses a private Firebase service account, high-entropy
webhook-secret check, and DB Vault to invoke the Edge function. No raw
Firebase token, secret value, or service-account JSON is included here or
in the repository. The cron retry job runs every five minutes and normal
report status updates do not depend on successful FCM delivery.

## Acceptance / next release step

**F05.2 acceptance criteria are met:**

1. Device notification token registered securely.
2. Backend delivered a targeted push to the intended Resident while the
   Android screen was locked.
3. Delivery failures are isolated from report status changes; queuing and
   retry logic have been tested.

Feature #24 may be closed as **Completed**. This is **not permission** to
merge integrated PR #46 into `main`, release publicly, or mark the full
project as signed off. Full-project Release Gate #47 still requires
lecturer/team approval and review of separately pending features (such as
password recovery redirect email acceptance if not yet verified).

## Evidence locations

- [F05.2 issue #24](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/24)
- [Release gate #47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47)
- [Hosted additive migration and database test log](HOSTED_RUNTIME_ROLLOUT_2026-11-22.md)
- [Backend architecture and secure FCM setup](FCM_SERVER_FINAL_ACTIVATION_2026-11-22.md)
