-- FixMate - public schema structural reference
-- Source: Supabase information_schema and pg_constraint exports supplied 2026-11-21.
--
-- IMPORTANT:
-- 1. Documentation / fresh-schema reference ONLY. DO NOT execute against the
--    current live Supabase project. Tables already exist there.
-- 2. Requires the standard Supabase auth.users table.
-- 3. Reconstructs the SIX public application tables, 34 columns, 10 foreign
--    keys, observed primary/unique/check constraints and column defaults.
-- 4. It does NOT include RLS policies, column/table grants, functions,
--    triggers, additional indexes, Storage objects, seed data or migration
--    history. It is NOT a full backup or production deployment migration.
-- 5. Identity sequence options were not inspected, so PostgreSQL defaults
--    are used for GENERATED ALWAYS AS IDENTITY.

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    full_name text NOT NULL DEFAULT '',
    role text NOT NULL DEFAULT 'resident',
    building text,
    room_number text,
    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT profiles_pkey PRIMARY KEY (id),
    CONSTRAINT profiles_id_fkey
        FOREIGN KEY (id) REFERENCES auth.users (id) ON DELETE CASCADE,
    CONSTRAINT profiles_role_check CHECK (
        role = ANY (ARRAY[
            'resident'::text,
            'maintenance_staff'::text,
            'moderator'::text,
            'system_admin'::text
        ])
    )
);

CREATE TABLE public.maintenance_categories (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    name text NOT NULL,
    is_active boolean NOT NULL DEFAULT true,

    CONSTRAINT maintenance_categories_pkey PRIMARY KEY (id),
    CONSTRAINT maintenance_categories_name_key UNIQUE (name)
);

CREATE TABLE public.maintenance_reports (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    resident_id uuid NOT NULL,
    category_id bigint NOT NULL,
    assigned_to uuid,
    title text NOT NULL,
    description text NOT NULL,
    location text,
    status text NOT NULL DEFAULT 'new',
    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT maintenance_reports_pkey PRIMARY KEY (id),
    CONSTRAINT maintenance_reports_resident_id_fkey
        FOREIGN KEY (resident_id) REFERENCES public.profiles (id),
    CONSTRAINT maintenance_reports_category_id_fkey
        FOREIGN KEY (category_id) REFERENCES public.maintenance_categories (id),
    CONSTRAINT maintenance_reports_assigned_to_fkey
        FOREIGN KEY (assigned_to) REFERENCES public.profiles (id),
    CONSTRAINT maintenance_reports_status_check CHECK (
        status = ANY (ARRAY[
            'new'::text,
            'in_progress'::text,
            'resolved'::text
        ])
    )
);

CREATE TABLE public.report_attachments (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    report_id bigint NOT NULL,
    uploaded_by uuid NOT NULL,
    storage_path text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT report_attachments_pkey PRIMARY KEY (id),
    CONSTRAINT report_attachments_report_id_fkey
        FOREIGN KEY (report_id)
        REFERENCES public.maintenance_reports (id) ON DELETE CASCADE,
    CONSTRAINT report_attachments_uploaded_by_fkey
        FOREIGN KEY (uploaded_by) REFERENCES public.profiles (id)
);

CREATE TABLE public.report_notes (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    report_id bigint NOT NULL,
    author_id uuid NOT NULL,
    content text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT report_notes_pkey PRIMARY KEY (id),
    CONSTRAINT report_notes_report_id_fkey
        FOREIGN KEY (report_id)
        REFERENCES public.maintenance_reports (id) ON DELETE CASCADE,
    CONSTRAINT report_notes_author_id_fkey
        FOREIGN KEY (author_id) REFERENCES public.profiles (id)
);

CREATE TABLE public.report_status_history (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    report_id bigint NOT NULL,
    changed_by uuid,
    old_status text,
    new_status text NOT NULL,
    changed_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT report_status_history_pkey PRIMARY KEY (id),
    CONSTRAINT report_status_history_report_id_fkey
        FOREIGN KEY (report_id)
        REFERENCES public.maintenance_reports (id) ON DELETE CASCADE,
    CONSTRAINT report_status_history_changed_by_fkey
        FOREIGN KEY (changed_by) REFERENCES public.profiles (id),
    CONSTRAINT report_status_history_new_status_check CHECK (
        new_status = ANY (ARRAY[
            'new'::text,
            'in_progress'::text,
            'resolved'::text
        ])
    )
);

-- Schema reconstruction complete for these six tables only.
-- See docs/DATABASE_RLS_SECURITY.md for observed authorization controls.
