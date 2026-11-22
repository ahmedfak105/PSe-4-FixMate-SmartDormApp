# FixMate — Run the Application (Android + Flutter Web)

**Build branch:** `integration/lecturer-review-2026-11-22`  
**Scope:** connected application builds; final production acceptance still requires the release gate.  
**Backend:** existing hosted Supabase project `epsvagztisdovixlqehi` has the original six public application tables. It has **not** received the proposed Moderator review table/RPC or report-validation migration.

## A. Android phone — use the connected APK

1. Open [Integrated Release Candidate Actions runs](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/workflows/integrated-release.yml) and select the **latest successful run** for the integration branch.
2. Open **Artifacts** and download `fixmate-integrated-connected-android-apk`. This is a ZIP. Extract its `app-debug.apk` and install it on an Android phone. GitHub artifact downloads may require a signed-in account; debug APKs are for testing, not Play Store distribution.
3. Open FixMate, sign in with an **existing authorized account** or use Resident sign-up if enabled in the project. Profiles route Residents and Maintenance Staff to their appropriate workspaces; Moderator and Admin workflows require corresponding authorized roles and deployed backend functions. Only accounts registered in the hosted Supabase Auth project can sign in.
4. Test Resident submit / My Reports / details / photos or Staff queue / claim / status / notes. Use your own authorized maintenance report data, not preloaded or pretend sample reports. The private report photos remain protected by Supabase Storage policies.
5. If the APK cannot sign in, check Auth email confirmation/provider configuration and user role. This connected APK uses the active project's **public publishable key only**, never `service_role` / `sb_secret`.

**Only the connected Android APK is published.** Builds without valid public Supabase settings show an error/connection-required screen; there is no local report database or offline APK.

## B. Published Flutter Web — all four roles

The integrated Flutter Web site was **successfully deployed on GitHub Pages**
from `7f035cd1` on **22 November 2026**. GitHub Actions confirmed both
the build and the deployment in [run #45037533703](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/45037533703).

**Open the published site:** https://ahmedfak105.github.io/PSe-4-FixMate-SmartDormApp/

The published build is configured with the project's **public-only Supabase
publishable key**. Sign in through Supabase Auth as Resident, Maintenance Staff,
Moderator or System Admin; routing is based on the current account's profile
role. Never enter private database, Firebase service-account or `sb_secret_`
values into the browser.

A successful deploy does **not** prove every hosted backend feature works.
The existing six-table server still has no Moderator review RPC or photo-avatar
Storage. Only currently installed and authorized backend actions can succeed.
See the current [hosted release audit](HOSTED_RELEASE_AUDIT_2026-11-22.md).

## C. Four-role connected application

Resident, Maintenance Staff, Moderator and System Admin all use Supabase
authentication. Their access and visibility depend on hosted role/RLS rules.
Moderator reviews, avatar uploads and certain admin/notification actions
remain unavailable until reviewed additive-only changes are deployed
safely under Release Gate #47. Never present unfinished hosted workflows
as already operational. Automated synthetic test fixtures under `test/`
and the disposable local Supabase CLI remain **developer-only tests**.

## D. Final acceptance

- Confirm the connected Android APK artifact build and actual installation/sign-in on a physical device.
- Confirm Pages deployment URL by a successful GitHub Actions deploy and actual browser login.
- Confirm no privileged client keys, and perform cross-account denied-access tests using synthetic accounts.
- For hosted Moderator review and input validation, [Release Gate #47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47) requires approved staging, verified backup and restore, reconciliation of existing empty migration history, and review of only additive SQL.
- The [integrated PR #46](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/46) is **not merged** merely because build artifacts exist.
