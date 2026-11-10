# FixMate Product Backlog

This document is the source-of-truth index for the initial Product Backlog. Detailed descriptions and acceptance criteria are maintained in the linked GitHub Issues.

## Product scope

FixMate is a smart dormitory maintenance reporting system. Residents use a Flutter mobile app to report and track issues. Maintenance personnel and administrators use a Flutter Web admin panel. Supabase provides the backend services.

## Backlog structure

- **6 Epics**
- **22 Features**
- Implementation tasks, technical subtasks, sprint commitments, and team assignments are intentionally deferred until the team agrees on the MVP.

## Epics and Features

### EPIC-01 — User Authentication & Access Control (#1)
| Feature | Issue |
|---|---:|
| F01.1 User Registration | [#7](../issues/7) |
| F01.2 User Login & Logout | [#8](../issues/8) |
| F01.3 Password Recovery | [#9](../issues/9) |
| F01.4 Role-Based Access Control (RBAC) | [#10](../issues/10) |
| F01.5 User Profile Management | [#11](../issues/11) |

### EPIC-02 — Maintenance Issue Reporting (#2)
| Feature | Issue |
|---|---:|
| F02.1 Submit Maintenance Report | [#12](../issues/12) |
| F02.2 Attach Photos to Reports | [#13](../issues/13) |
| F02.3 Select Maintenance Category | [#14](../issues/14) |
| F02.4 Validate Report Information | [#15](../issues/15) |

### EPIC-03 — Maintenance Report Management (#3)
| Feature | Issue |
|---|---:|
| F03.1 View Submitted Reports | [#16](../issues/16) |
| F03.2 Review Maintenance Reports | [#17](../issues/17) |
| F03.3 Assign Reports to Maintenance Staff | [#18](../issues/18) |
| F03.4 Update Report Status | [#19](../issues/19) |
| F03.5 Add Maintenance Notes | [#20](../issues/20) |

### EPIC-04 — Resident Report Tracking (#4)
| Feature | Issue |
|---|---:|
| F04.1 View My Reports | [#21](../issues/21) |
| F04.2 View Report Details and Track Progress | [#22](../issues/22) |

### EPIC-05 — Notifications (#5)
| Feature | Issue |
|---|---:|
| F05.1 Report Status Change Notifications | [#23](../issues/23) |
| F05.2 Push Notification Delivery | [#24](../issues/24) |

### EPIC-06 — Administration & System Configuration (#6)
| Feature | Issue |
|---|---:|
| F06.1 Administrative Dashboard | [#25](../issues/25) |
| F06.2 User and Role Administration | [#26](../issues/26) |
| F06.3 Maintenance Category Management | [#28](../issues/28) |
| F06.4 Report Search and Filtering | [#29](../issues/29) |

## User roles and access boundaries

| Role | Main responsibilities | Access boundary |
|---|---|---|
| Resident | Register, submit reports, attach photos, view own reports, track status, receive notifications | Can access only their own private reports and profile |
| Maintenance Staff | View assigned reports, update status, add maintenance notes | Cannot administer users or roles |
| Moderator / Content Admin | Review reports, identify duplicates or inappropriate submissions, assign reports, manage categories if authorized | Cannot grant System Admin privileges or manage owner-level access |
| System Admin | Manage users, roles, categories, and system configuration | Administrative access; sensitive actions should be auditable |

## Proposed GitHub Project configuration

Create a GitHub Project (Projects → New project → Board) named **FixMate Product Backlog** and add the repository's Issues.

Recommended fields:
- **Status:** Backlog, Ready, In Progress, In Review, Done
- **Priority:** P0, P1, P2, P3
- **Work Type:** Epic, Feature, Task
- **Component:** Mobile, Admin Web, Backend, Notifications
- **Parent Epic:** text or single-select reference to EPIC-01 through EPIC-06 (if a custom field is available)

Recommended labels:
- `type:epic`, `type:feature`, `type:task`
- `priority:P0`, `priority:P1`, `priority:P2`, `priority:P3`
- `area:mobile`, `area:admin-web`, `area:backend`, `area:notifications`

Priority meanings:
- **P0 — Critical:** required for the core product workflow.
- **P1 — High:** important, but not necessarily required for the first end-to-end demo.
- **P2 — Medium:** useful enhancement.
- **P3 — Low:** optional / future improvement.

All current priorities are provisional and must be reviewed by the team during MVP selection.

## Workflow guidance

1. Keep Epics and Features in Backlog until the team has reviewed and accepted them.
2. Select a small end-to-end MVP before creating implementation tasks.
3. Break accepted Features into technical tasks only during sprint planning.
4. Assign tasks only after team capacity and responsibilities are agreed.
5. Move an item to Done only when its acceptance criteria are satisfied and verified.

## Scope decisions and open points

- Current backlog assumes one dormitory/service context. Multi-dorm support is not included unless the lecturer/team confirms it.
- Social sign-in (Google/Apple) is not part of the current core scope; add it only if explicitly required.
- Resident self-registration must never allow users to choose privileged roles.
- Push notification delivery depends on supported device/platform configuration and free-tier quotas.
- P0/P1 priorities are initial proposals, not a final MVP commitment.

## Notes

The Epic issues link to their child Feature issues. Each Feature issue contains its own description and acceptance criteria. One duplicate F06.2 issue was closed; the canonical Feature is issue #26.
