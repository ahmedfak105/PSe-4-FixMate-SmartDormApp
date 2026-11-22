# FixMate — Run the Application (Android + Flutter Web)

**Build branch:** `integration/lecturer-review-2026-11-22`  
**Scope:** connected application builds; final production acceptance still requires the release gate.  
**Backend:** existing hosted Supabase project `epsvagztisdovixlqehi` has the original six public application tables. It has **not** received the proposed Moderator review table/RPC or report-validation migration.

## A. Android phone — use the connected APK

1. Open [Integrated Release Candidate Actions runs](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/workflows/integrated-release.yml) and select the **latest successful run** for the integration branch.
2. Open **Artifacts** and download `fixmate-integrated-connected-android-apk`. This is a ZIP. Extract its `app-debug.apk` and install it on an Android phone. GitHub artifact downloads may require a signed-in account; debug APKs are for testing, not Play Store distribution.
3. Open FixMate, sign in with an **existing authorized Resident or Maintenance Staff account** or use Resident sign-up if enabled in the project. Only accounts registered in the hosted Supabase Auth project can sign in.
4. Test Resident submit / My Reports / details / photos or Staff queue / claim / status / notes. Only test using authorized sample data. The private report photos remain protected by Supabase Storage policies.
5. If the APK cannot sign in, check Auth email confirmation/provider configuration and user role. This connected APK uses the active project's **public publishable key only**, never `service_role` / `sb_secret`.

**Only the connected Android APK is published.** Builds without valid public Supabase settings show an error/connection-required screen; there is no local report database or offline APK.

## B. Flutter Web operations — GitHub Pages

The repository contains [the Pages deployment workflow](../.github/workflows/deploy-flutter-web-pages.yml). It builds a real Flutter Web operations UI with the repository subpath `/PSe-4-FixMate-SmartDormApp/`, with the hosted project's **public publishable key** compiled into the browser bundle (no secret or privileged keys). It **may not be live yet** until the repository owner enables Pages and a successful deployment is verified.

1. Repository administrator: open [Settings → Pages](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/settings/pages) and set **Build and deployment → Source: GitHub Actions**.
2. In [Actions → FixMate Operations Web — GitHub Pages](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/workflows/deploy-flutter-web-pages.yml), run the workflow on the integration branch (or inspect an automatically triggered run). Confirm both `build` and `deploy` succeed.
3. **Only if the deployment succeeds**, open the Pages URL reported by that run (usually `https://ahmedfak105.github.io/PSe-4-FixMate-SmartDormApp/`; never assume it exists before success).
4. The Pages build is already configured to use `https://epsvagztisdovixlqehi.supabase.co` with a **public-only** API key. You should see the login page directly, without entering server configuration. Never enter `sb_secret`, service-role keys or database passwords.
5. Log in with an existing `maintenance_staff` or `system_admin` profile. The Moderator page **cannot save reviews** on the six-table hosted database; this requires the separate approved staging/release gate. A Resident is deliberately denied access to the operations website.

If Pages deployment is unavailable due to repository permissions, use the web ZIP from [Integrated Release Candidate](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/workflows/integrated-release.yml) and publish its contents on an HTTPS static host, preserving the base-path configuration (the generic web artifact in that workflow targets root `/`, so it should not be mounted under a subpath without rebuilding).

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
