# FixMate — F01.3 Password Recovery (zero-cost setup and acceptance)

## Implemented in Flutter

- Resident, Staff, Moderator and Admin login screens offer **Forgot password?**
- A validated email address is passed to Supabase `auth.resetPasswordForEmail` using a FixMate-only callback.
- The confirmation screen always says *If an account matches that email address…* so it does not confirm whether the user exists.
- The callback opens the authenticated **Choose a new password** form, not the ordinary dashboard. The UI listens for `AuthChangeEvent.passwordRecovery` and has an early-init web landing fallback.
- Form checks password length and confirmation; calls `auth.updateUser(UserAttributes(password: …))`, signs out, then requires a fresh login.
- No role changes, service-role keys or new SQL are needed. Android intent-filter deep-link callback is registered.
- Unit/widget tests cover invalid address, neutral response, provider failure, invalid session, password validation and successful password update/sign-out.

## One-time hosted Auth configuration (free; project owner action)

Supabase Dashboard → Authentication → URL Configuration → **Redirect URLs**:

1. Add exact URL: `https://ahmedfak105.github.io/PSe-4-FixMate-SmartDormApp/?fixmate_recovery=1`
2. Add exact Android URI: `com.fixmate.smartdorm://reset-password`
3. Save. Do **not** change the already working main Site URL, policies or JWT secret.

The Flutter web app must be served at the same GitHub Pages path, and the Android APK must be rebuilt after the intent-filter change. If another URL is used, pass the approved callback by `--dart-define=FIXMATE_PASSWORD_RESET_REDIRECT_URL=...` and allowlist that exact URL. Never allow `*` redirect patterns across untrusted domains.

**IMPORTANT:** These Redirect URLs cannot be edited by the currently linked Supabase project actions; an authorized project owner must configure them in the Dashboard.

## Free testing without real emails

- The existing Supabase CLI stack (local PostgreSQL/Auth/Mailpit) handles recovery email during development without any paid service.
- The Flutter widget tests use stub send/update functions so they cannot send emails or modify accounts.
- GitHub Actions CLI and Flutter test jobs are subject to the free quota of the repository/account.
- Hosted default Supabase SMTP is **best effort** and currently documented as low-rate (e.g. two emails/hour). Do not assume reliable production-wide delivery or subscribe to a paid provider without approval.
- No live user account should be used for an automated reset. For manual hosted acceptance, use an authorized synthetic Resident account and a controlled mailbox.

## Hosted acceptance checklist — keep #9 In Progress until done

- [x] Recovery request UI and account-neutral messaging
- [x] Authenticated new password UI and sign-out after update
- [x] Android callback registration and web path preservation
- [x] Deterministic free Flutter widget tests (subject to latest green CI)
- [ ] Set exact allowed redirect URLs in hosted Supabase
- [ ] Test a real recovery email to a test mailbox on the hosted project
- [ ] Click emailed link and verify Web page opens **Choose a new password**; repeat on a newly built Android APK
- [ ] Confirm old password no longer works and new password authenticates; no roles/profiles changed
- [ ] Repeat an invalid-account request to verify generic public response and check any SMTP rate limits

**Feature lifecycle:** #9 is In Progress, not Done until callback configuration and hosted test confirmation. No live migrations are required.
