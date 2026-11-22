# FixMate — hosted 11-table ERD (22 November 2026)

The diagram below reflects the **11 actual application tables in
`public`** after nine additive hosted Supabase migrations. Every table
has Row Level Security (RLS) enabled. `auth.users` belongs to Supabase,
and private Storage object payloads are not held in `public` tables.
This supersedes the **historical six-table** ERD for the current hosted
academic test environment.

```mermaid
erDiagram
    AUTH_USERS ||--o| PROFILES : owns
    PROFILES ||--o{ MAINTENANCE_REPORTS : submits
    PROFILES o|--o{ MAINTENANCE_REPORTS : assigned_staff
    MAINTENANCE_CATEGORIES ||--o{ MAINTENANCE_REPORTS : categorizes
    MAINTENANCE_REPORTS ||--o{ REPORT_ATTACHMENTS : has
    PROFILES ||--o{ REPORT_ATTACHMENTS : uploads
    MAINTENANCE_REPORTS ||--o{ REPORT_NOTES : has
    PROFILES ||--o{ REPORT_NOTES : authors
    MAINTENANCE_REPORTS ||--o{ REPORT_STATUS_HISTORY : history
    PROFILES o|--o{ REPORT_STATUS_HISTORY : changes
    MAINTENANCE_REPORTS ||--o| REPORT_REVIEWS : moderation
    PROFILES ||--o{ REPORT_REVIEWS : reviews
    PROFILES ||--o{ USER_ROLE_AUDIT : actor
    PROFILES ||--o{ USER_ROLE_AUDIT : target
    MAINTENANCE_REPORTS ||--o{ REPORT_NOTIFICATIONS : status_alerts
    PROFILES ||--o{ REPORT_NOTIFICATIONS : receives
    PROFILES ||--o{ PUSH_DEVICE_TOKENS : registers
    REPORT_NOTIFICATIONS ||--o{ PUSH_DELIVERY_OUTBOX : queues
    PROFILES ||--o{ PUSH_DELIVERY_OUTBOX : receiver

    AUTH_USERS {
        uuid id PK
    }
    PROFILES {
        uuid id PK,FK
        text full_name
        text role
        text building
        text room_number
        text avatar_path
        timestamptz created_at
    }
    MAINTENANCE_CATEGORIES {
        bigint id PK
        text name UK
        boolean is_active
    }
    MAINTENANCE_REPORTS {
        bigint id PK
        uuid resident_id FK
        bigint category_id FK
        uuid assigned_to FK
        text title
        text description
        text location
        text status
        timestamptz created_at
    }
    REPORT_ATTACHMENTS {
        uuid id PK
        bigint report_id FK
        uuid uploaded_by FK
        text storage_path
        timestamptz created_at
    }
    REPORT_NOTES {
        bigint id PK
        bigint report_id FK
        uuid author_id FK
        text content
        timestamptz created_at
    }
    REPORT_STATUS_HISTORY {
        bigint id PK
        bigint report_id FK
        uuid changed_by FK
        text old_status
        text new_status
        timestamptz changed_at
    }
    REPORT_REVIEWS {
        bigint report_id PK,FK
        uuid reviewer_id FK
        text outcome
        text reason
        timestamptz reviewed_at
    }
    USER_ROLE_AUDIT {
        bigint id PK
        uuid actor_id FK
        uuid target_id FK
        text old_role
        text new_role
        timestamptz changed_at
    }
    REPORT_NOTIFICATIONS {
        bigint id PK
        uuid resident_id FK
        bigint report_id FK
        text new_status
        timestamptz created_at
        timestamptz read_at
    }
    PUSH_DEVICE_TOKENS {
        text token PK
        uuid user_id FK
        text platform
        timestamptz created_at
        timestamptz last_seen_at
    }
    PUSH_DELIVERY_OUTBOX {
        bigint id PK
        bigint notification_id FK
        uuid resident_id FK
        text token
        text token_fingerprint
        text state
        int attempts
        timestamptz next_attempt_at
    }
```

## Design notes

- `auth.users` has a one-to-one relationship with `profiles`;
  other `public` tables use `profiles.id` for ownership, review,
  staff and audit references.
- A report can have many attachments, notes, status-history rows,
  and notifications, but at most one immutable moderation review.
- `report_reviews` tracks Moderator decisions (`valid`, `duplicate`,
  `inappropriate`). Rejected reports cannot be assigned or moved to
  in-progress state.
- `push_delivery_outbox.notification_id` points to a stored in-app
  status notification. The delivery `token` is a snapshot string, not
  a foreign key to `push_device_tokens.token`: a database trigger
  cancels queued jobs if a token is unregistered.
- Photo bytes are stored separately in private Supabase Storage
  buckets `report-photos` and `profile-avatars`. `storage_path`
  and `avatar_path` are text metadata, not foreign keys to
  `storage.objects` in this application schema.
- `push_delivery_outbox` has RLS enabled but no client-facing policies
  or table grants. The trusted server accesses it with a privileged
  credential; it is not exposed to Residents or Staff.
- The 11 application tables do **not** count the Supabase-managed
  `auth.users` table or Storage internal tables.
