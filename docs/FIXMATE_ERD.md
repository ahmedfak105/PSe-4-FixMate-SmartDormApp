# FixMate — Entity Relationship Diagram

This diagram is based on the six actual `public` tables and the foreign-key constraints exported from Supabase on 21 November 2026. `auth.users` appears as an external, Supabase-managed authentication entity.

```mermaid
%% FixMate – SmartDormApp database ERD
%% Source: actual public schema exports supplied 2026-11-21.
%% auth.users is managed by Supabase and is not one of the six application tables.
%% PK/FK fields are marked; nullable FKs are noted in the relationship and field descriptions.
erDiagram
    AUTH_USERS ||--o| PROFILES : "id (auth identity)"
    PROFILES ||--o{ MAINTENANCE_REPORTS : "resident_id"
    PROFILES o|--o{ MAINTENANCE_REPORTS : "assigned_to (nullable)"
    MAINTENANCE_CATEGORIES ||--o{ MAINTENANCE_REPORTS : "category_id"
    MAINTENANCE_REPORTS ||--o{ REPORT_ATTACHMENTS : "report_id"
    PROFILES ||--o{ REPORT_ATTACHMENTS : "uploaded_by"
    MAINTENANCE_REPORTS ||--o{ REPORT_NOTES : "report_id"
    PROFILES ||--o{ REPORT_NOTES : "author_id"
    MAINTENANCE_REPORTS ||--o{ REPORT_STATUS_HISTORY : "report_id"
    PROFILES o|--o{ REPORT_STATUS_HISTORY : "changed_by (nullable)"

    AUTH_USERS {
        uuid id PK
    }
    PROFILES {
        uuid id PK, FK
        text full_name
        text role
        text building "nullable"
        text room_number "nullable"
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
        uuid assigned_to FK "nullable"
        text title
        text description
        text location "nullable"
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
        uuid changed_by FK "nullable"
        text old_status "nullable"
        text new_status
        timestamptz changed_at
    }
```

**How to interpret the diagram:** the central `maintenance_reports` table belongs to a resident, refers to one category and can optionally be assigned to a staff profile. Reports can have multiple attachments, internal notes and status-history entries. `profiles.id` is also a foreign key to `auth.users.id`.

The source can be edited in [FIXMATE_ERD.mmd](erd/FIXMATE_ERD.mmd). Check [Database Architecture](DATABASE_ARCHITECTURE.md) for an explanation of the exact foreign keys, column types, identities and authorization rules.
