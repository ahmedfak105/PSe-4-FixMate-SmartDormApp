> **Current implementation acceptance — 22 Nov 2026:** The original **12/12 TASK issues are closed** following reproducible local Flutter/Supabase/API/Storage/Chrome tests. Five CLI-named migrations build a fresh local environment including report validation and Moderator review. **This is NOT hosted deployment or lecturer final sign-off.** The populated remote still has the original six application tables and empty migration history; [RELEASE GATE #47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47) tracks approved backup/staging/reconciliation/target-project deployment. [Integrated Draft PR #46](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/46) remains unmerged.

# FixMate — Final integration and lecturer delivery checklist

**Verified:** 22 November 2026. **Status:** Release preparation; no production deployment or PR merges performed.

## Current source of truth

The `main` branch currently contains only `README.md` and `docs/PRODUCT_BACKLOG.md`; it does **not** yet contain the implementation. Current PRs:

| PR | Role | Review state |
|---|---|---|
| [#42 — Database, security and evidence](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/42) | Docs, local reproducible baseline migrations, database tests | Draft, unmerged |
| [#43 — Flutter Resident/Staff](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/43) | Mobile code, signup, submissions, staff workflows and Android build | Draft, unmerged |
| [#45 — Flutter Web Operations](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/45) | Admin/Moderator/Staff Flutter Web, **stacked on PR #43** | Draft, unmerged |
| [#44 — Earlier standalone Admin Web](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/44) | HTML/JS prototype (separate from requested Flutter Web) | Draft, unmerged; optional/reference |

**Integration recommendation:** Review #42 and #43, then bring #45 onto the default branch *after #43* with the actual Flutter Web application. Treat #44 as an optional prototype or reference only; do **not** substitute it for Flutter Web or accidentally deploy two conflicting admin applications. Resolve any conflicts, rerun all workflows on the final integration commit and obtain reviewer sign-off before merging. Merely checking green PRs on different bases is not proof the final combined `main` is green.

## What has passed

- [Flutter Web app tests](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44962305057) — Success.
- [Flutter Web release build](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44962305085) — Success.
- [Real Flutter Web Chromium E2E](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44962305056) — Success; role routing, Admin/Moderator/Staff workflows on disposable Supabase.
- [Reproducible local Supabase migration reset and API tests](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44957264386) — Success.
- [Isolated concurrent staff Claim race](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44956576887) — Success.
- [Android debug APK build](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44957841608) — Success.

These are automated development/test results, not screenshots or an installed hosted deployment. Do not assume time-limited GitHub Actions artifacts are permanent.

## Two original TASK issues closed locally; hosted rollout separate

| Task | Present state | Actual acceptance gate |
|---|---|---|
| [#36 — Report backend/Storage policies](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/36) | **Closed / Done at implementation acceptance**; five-file local migration replay, Auth/API/Storage negative tests pass | Hosted deployment is still separately gated in #47 |
| [#39 — Moderator review](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/39) | **Closed / Done at implementation acceptance**; Flutter Web Chrome E2E and local Moderator RPC persisted outcomes | Hosted review table/RPC still missing; deployment is separately gated in #47 |

The original task acceptance criteria were matched to tested code and the two issues were closed **as implemented locally**, not as a production release. Follow [controlled rollout and rollback gates](CONTROLLED_SUPABASE_ROLLOUT_TASK36_TASK39.md) and [read-only preflight](sql/REMOTE_ADDITIVE_PREDEPLOY_READ_ONLY.sql). The existing active Supabase database has six tables and **no recorded migration history**; never execute the fresh baseline migrations against it.

## Release candidate sign-off sequence

- [ ] Reviewer approves PR #42 database documentation and validates that it contains **fresh-project** migrations, not a remote upgrade of the existing database.
- [ ] Reviewer approves PR #43 Flutter app and its Android artifacts.
- [ ] Reviewer approves PR #45 after #43; verify the Flutter Web build still passes on the integrated SHA. Decide how to label/retain the older optional HTML/JS PR #44.
- [ ] Integrate and run: Flutter analyze/test, Android APK build, Flutter Web release build, local Supabase reset, Auth/REST/Storage E2E, Flutter Web Chromium E2E, concurrency and database validation smoke.
- [ ] Provision a separate approved staging/clone or local demo Supabase instance (no real secrets or production user copies). Apply/additive test the two proposed Task #36/#39 scripts; document backup/restore and project-specific negative RLS tests.
- [ ] Fix any UI errors from actual browser/device runs and capture screenshots/video of Resident, Staff, Moderator and Admin demonstrations with synthetic users.
- [ ] Sync GitHub Project board card Status values with the **issue state** and remaining acceptance checklists. Closed issues alone may not update the board.
- [ ] Prepare lecturer handoff: updated ERD (baseline six tables + separately labeled proposed Moderator seventh table), source/SQL/CI links, English 7-minute script, and an honest list of unfinished backlog features (e.g. push notifications, password recovery).

**Go/no-go:** No merge of unreviewed Draft PRs, no production database SQL, no third-party hosting deployment and no real user creation have been performed by this checklist. The requested next phase is *integration review plus a controlled staging release*, not new feature work.
