# FixMate — Staging Acceptance and Release Decision Record

**Status:** NOT APPROVED / NOT DEPLOYED  
**Prepared:** 2026-11-22  
**Scope:** Original TASK #36 report validation and TASK #39 Moderator reviews only  
**Tracking:** [Release Gate #47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47) · [Integrated Draft PR #46](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/pull/46)

> This is an evidence form for an authorized reviewer. Blank entries mean **not verified**. This document does not authorize a deployment or claim that tests have run against hosted Supabase. The existing populated project must never receive the five fresh-baseline migrations through a naive `supabase db push`.

## 1. Candidate identity (fill before review)

| Field | Recorded value |
| --- | --- |
| Integrated branch | `integration/lecturer-review-2026-11-22` |
| Exact reviewed commit SHA | PENDING |
| Flutter APK / Web artifact run and retention | PENDING |
| Additive SQL #36 SHA-256 | PENDING |
| Additive SQL #39 SHA-256 | PENDING |
| Exact hosted Supabase project reference (private record) | PENDING |
| Separate approved staging project reference (private record) | PENDING |
| Database owner / deploy operator / reviewer | PENDING |
| Planned maintenance window | PENDING |

## 2. Evidence already established in isolated local CI

These are *development* results, not staging or hosted deployment acceptance.

| Check | Local evidence |
| --- | --- |
| Five-migration PostgreSQL schema smoke | [Successful CI run](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44964869207) |
| Supabase Auth / REST / RLS / Storage | [Successful local CI run](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44964866869) |
| Real Flutter Web Chrome E2E | [Successful local CI run](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44964869271) |
| Reproducible four-role local demo | [Successful local CI run](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/actions/runs/44964866875) |

## 3. Required preconditions — stop if any is missing

- [ ] Lecturer/team reviewed integration diff and approved the target scope and merge policy.
- [ ] Staging Supabase project/branch approved, cost checked, and isolated from actual accounts/photos/secrets.
- [ ] Existing hosted schema and Resident INSERT policy captured using [read-only preflight](sql/REMOTE_ADDITIVE_PREDEPLOY_READ_ONLY.sql); output archived.
- [ ] Existing hosted database backup created **and restoration demonstrated** on an authorized non-production target.
- [ ] Existing six-table remote baseline and empty migration history formally reconciled; no live table reset/drop.
- [ ] Exact additive #36 and #39 scripts approved; checksums captured.
- [ ] No leaked service-role/secret keys in mobile or Flutter Web client; RLS/Storage controls retained.
- [ ] Supabase Auth settings, password protection, SMTP/email, Security/Performance advisors reviewed.

## 4. Staging test matrix

Record **PASS / FAIL / NOT RUN**, tester, timestamp, evidence link, and observed backend state for every row. A user-interface screenshot alone is not sufficient evidence of RLS or persistence.

| Test | Expected outcome | Result | Evidence / tester |
| --- | --- | --- | --- |
| Resident sign-up and sign-in | New user receives Resident profile; no privileged role | NOT RUN | — |
| Resident valid report and private photo | Report/attachment saved and owned by Resident | NOT RUN | — |
| Resident invalid fields/inactive category | Database rejects invalid submission | NOT RUN | — |
| Resident foreign report and foreign photo | Both reads denied by RLS/Storage | NOT RUN | — |
| Resident tries Staff/Admin/Moderator operations | All denied by backend, not just hidden UI | NOT RUN | — |
| Moderator reads authorized report/private photo | Only intended permissions granted | NOT RUN | — |
| Moderator Valid review | Review persisted in `report_reviews` | NOT RUN | — |
| Moderator Duplicate/Inappropriate | Reason required; decision persisted | NOT RUN | — |
| Rejected report attempted assignment/claim | Database trigger rejects operation | NOT RUN | — |
| Maintenance Staff simultaneous claim | Exactly one claimant succeeds | NOT RUN | — |
| Staff claim, note and resolve | Authorized update and history persisted | NOT RUN | — |
| Admin dashboard and assignment | Role-authorized data and RPC assignment | NOT RUN | — |
| Admin/Staff cross-role negative checks | No unauthorized records/actions | NOT RUN | — |
| Flutter Web real Chromium E2E | All defined integration assertions pass | NOT RUN | — |
| Hosted/configured Android smoke | Login, submit, status and photo behaviors work | NOT RUN | — |
| Existing report regression | Historical records unchanged and viewable | NOT RUN | — |

## 5. Go / No-Go

| Sign-off | Decision | Identity / date / evidence |
| --- | --- | --- |
| Database owner — backup and migration reconciliation | PENDING | — |
| Team code reviewer — exact SHA and SQL checksums | PENDING | — |
| Staging tester — full matrix | PENDING | — |
| Lecturer / release scope | PENDING | — |
| Authorized live deployment operator | PENDING | — |

**Default decision: NO-GO.** Only after every gate is evidenced may the project owner authorize an explicitly controlled, additive rollout. Staging completion does not itself deploy the hosted project.

## 6. After authorized hosted rollout

Record deployed commit and SQL checksums, table/RPC/trigger inventory, database owner, smoke tests, RLS/photo regression tests, Android/Web device testing, Supabase advisor findings, and incident/forward-fix contact. Preserve Moderator review data on failure; do not blindly drop the review table or disable RLS. Update [#47](https://github.com/ahmedfak105/PSe-4-FixMate-SmartDormApp/issues/47) with direct evidence and close only after acceptance.

**References:** [Controlled rollout / rollback instructions](CONTROLLED_SUPABASE_ROLLOUT_TASK36_TASK39.md) · [Lecturer handoff](LECTURER_REVIEW_START_HERE.md).
