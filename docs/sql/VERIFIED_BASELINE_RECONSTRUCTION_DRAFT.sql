-- FixMate BASELINE RECONSTRUCTION DRAFT, captured from the live project's
-- read-only catalog on 2026-11-22. NOT RUN, NOT TESTED, NOT a signed-off migration.
-- DO NOT APPLY TO THE EXISTING SUPABASE PROJECT (it already contains these objects).
-- Intended ONLY for a NEW EMPTY Supabase staging database after review.
-- Contains no Auth users, passwords, data or objects from private Storage.
-- A new Supabase instance must have auth.users, storage.objects and built-in
-- roles/schemas. Functions copied verbatim from pg_get_functiondef.
-- Existing 6-table schema was cross-checked against pg_constraint.
-- Policies copied from pg_policies, meaning this snapshot can include design
-- issues; these are NOT silently corrected by the exporter.
-- CLI-generated migration history, project settings, and actual E2E tests are
-- still required to call this a reproducible deployment.
-- See docs/SUPABASE_LIVE_AUDIT_2026-11-22.md.
BEGIN;

SET LOCAL search_path = public, auth, storage;
CREATE SCHEMA IF NOT EXISTS private;
CREATE SCHEMA IF NOT EXISTS fixmate_private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SCHEMA fixmate_private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA fixmate_private TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- 1. Existing public tables, keys and CHECK constraints
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

-- One existing non-constraint unique index (not in earlier schema reference).
CREATE UNIQUE INDEX report_attachments_storage_path_unique
  ON public.report_attachments USING btree (storage_path);

-- 2. Exact current application functions (from pg_get_functiondef)

-- Captured: private.handle_new_user()
CREATE OR REPLACE FUNCTION private.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
    INSERT INTO public.profiles (
            id,
                    full_name,
                            role
                                )
                                    VALUES (
                                            NEW.id,
                                                    COALESCE(
                                                                NEW.raw_user_meta_data ->> 'full_name',
                                                                            ''
                                                                                    ),
                                                                                            'resident'
                                                                                                )
                                                                                                    ON CONFLICT (id) DO NOTHING;

                                                                                                        RETURN NEW;
                                                                                                        END;
                                                                                                        $function$;

-- Captured: fixmate_private.current_user_is_system_admin()
CREATE OR REPLACE FUNCTION fixmate_private.current_user_is_system_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
    SELECT EXISTS (
            SELECT 1
                    FROM public.profiles AS p
                            WHERE p.id = (SELECT auth.uid())
                                      AND p.role = 'system_admin'
                                          );
                                          $function$;

-- Captured: fixmate_private.claim_maintenance_report(p_report_id bigint)
CREATE OR REPLACE FUNCTION fixmate_private.claim_maintenance_report(p_report_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                                                                                                                                                            DECLARE
                                                                                                                                                                                v_staff_id UUID := auth.uid();
                                                                                                                                                                                    v_report_id BIGINT;
                                                                                                                                                                                    BEGIN
                                                                                                                                                                                        IF v_staff_id IS NULL OR NOT EXISTS (
                                                                                                                                                                                                SELECT 1
                                                                                                                                                                                                        FROM public.profiles
                                                                                                                                                                                                                WHERE id = v_staff_id
                                                                                                                                                                                                                          AND role = 'maintenance_staff'
                                                                                                                                                                                                                              ) THEN
                                                                                                                                                                                                                                      RAISE EXCEPTION 'Not authorized to claim reports';
                                                                                                                                                                                                                                          END IF;

                                                                                                                                                                                                                                              UPDATE public.maintenance_reports
                                                                                                                                                                                                                                                  SET assigned_to = v_staff_id,
                                                                                                                                                                                                                                                          status = 'in_progress'
                                                                                                                                                                                                                                                              WHERE id = p_report_id
                                                                                                                                                                                                                                                                    AND status = 'new'
                                                                                                                                                                                                                                                                          AND (
                                                                                                                                                                                                                                                                                    assigned_to IS NULL
                                                                                                                                                                                                                                                                                              OR assigned_to = v_staff_id
                                                                                                                                                                                                                                                                                                    )
                                                                                                                                                                                                                                                                                                        RETURNING id INTO v_report_id;

                                                                                                                                                                                                                                                                                                            IF v_report_id IS NULL THEN
                                                                                                                                                                                                                                                                                                                    RETURN FALSE;
                                                                                                                                                                                                                                                                                                                        END IF;

                                                                                                                                                                                                                                                                                                                            INSERT INTO public.report_status_history (
                                                                                                                                                                                                                                                                                                                                    report_id,
                                                                                                                                                                                                                                                                                                                                            changed_by,
                                                                                                                                                                                                                                                                                                                                                    old_status,
                                                                                                                                                                                                                                                                                                                                                            new_status
                                                                                                                                                                                                                                                                                                                                                                )
                                                                                                                                                                                                                                                                                                                                                                    VALUES (
                                                                                                                                                                                                                                                                                                                                                                            v_report_id,
                                                                                                                                                                                                                                                                                                                                                                                    v_staff_id,
                                                                                                                                                                                                                                                                                                                                                                                            'new',
                                                                                                                                                                                                                                                                                                                                                                                                    'in_progress'
                                                                                                                                                                                                                                                                                                                                                                                                        );

                                                                                                                                                                                                                                                                                                                                                                                                            RETURN TRUE;
                                                                                                                                                                                                                                                                                                                                                                                                            END;
                                                                                                                                                                                                                                                                                                                                                                                                            $function$;

-- Captured: fixmate_private.resolve_maintenance_report(p_report_id bigint)
CREATE OR REPLACE FUNCTION fixmate_private.resolve_maintenance_report(p_report_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
    DECLARE
        v_staff_id UUID := auth.uid();
            v_report_id BIGINT;
            BEGIN
                -- Check the user's role
                    IF v_staff_id IS NULL OR NOT EXISTS (
                            SELECT 1
                                    FROM public.profiles
                                            WHERE id = v_staff_id
                                                      AND role = 'maintenance_staff'
                                                          ) THEN
                                                                  RAISE EXCEPTION 'Not authorized';
                                                                      END IF;

                                                                          -- Resolve only a report assigned to this staff member
                                                                              UPDATE public.maintenance_reports
                                                                                  SET status = 'resolved'
                                                                                      WHERE id = p_report_id
                                                                                            AND assigned_to = v_staff_id
                                                                                                  AND status = 'in_progress'
                                                                                                      RETURNING id INTO v_report_id;

                                                                                                          IF v_report_id IS NULL THEN
                                                                                                                  RETURN FALSE;
                                                                                                                      END IF;

                                                                                                                          -- Save the status change
                                                                                                                              INSERT INTO public.report_status_history (
                                                                                                                                      report_id,
                                                                                                                                              changed_by,
                                                                                                                                                      old_status,
                                                                                                                                                              new_status
                                                                                                                                                                  )
                                                                                                                                                                      VALUES (
                                                                                                                                                                              v_report_id,
                                                                                                                                                                                      v_staff_id,
                                                                                                                                                                                              'in_progress',
                                                                                                                                                                                                      'resolved'
                                                                                                                                                                                                          );

                                                                                                                                                                                                              RETURN TRUE;
                                                                                                                                                                                                              END;
                                                                                                                                                                                                              $function$;

-- Captured: fixmate_private.assign_maintenance_report(p_report_id bigint, p_staff_id uuid)
CREATE OR REPLACE FUNCTION fixmate_private.assign_maintenance_report(p_report_id bigint, p_staff_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
        DECLARE
            v_manager_id UUID := auth.uid();
                v_report_id BIGINT;
                BEGIN
                    -- Only moderators and system admins
                        IF v_manager_id IS NULL OR NOT EXISTS (
                                SELECT 1
                                        FROM public.profiles
                                                WHERE id = v_manager_id
                                                          AND role IN ('moderator', 'system_admin')
                                                              ) THEN
                                                                      RAISE EXCEPTION 'Not authorized to assign reports';
                                                                          END IF;

                                                                              -- The selected user must be maintenance staff
                                                                                  IF p_staff_id IS NULL OR NOT EXISTS (
                                                                                          SELECT 1
                                                                                                  FROM public.profiles
                                                                                                          WHERE id = p_staff_id
                                                                                                                    AND role = 'maintenance_staff'
                                                                                                                        ) THEN
                                                                                                                                RAISE EXCEPTION 'Invalid maintenance staff';
                                                                                                                                    END IF;

                                                                                                                                        -- Assign an available report
                                                                                                                                            UPDATE public.maintenance_reports
                                                                                                                                                SET assigned_to = p_staff_id
                                                                                                                                                    WHERE id = p_report_id
                                                                                                                                                          AND status = 'new'
                                                                                                                                                                AND assigned_to IS NULL
                                                                                                                                                                    RETURNING id INTO v_report_id;

                                                                                                                                                                        RETURN v_report_id IS NOT NULL;
                                                                                                                                                                        END;
                                                                                                                                                                        $function$;

-- Captured: public.claim_maintenance_report(p_report_id bigint)
CREATE OR REPLACE FUNCTION public.claim_maintenance_report(p_report_id bigint)
 RETURNS boolean
 LANGUAGE sql
 SET search_path TO ''
AS $function$
                SELECT fixmate_private.claim_maintenance_report($1);
                $function$;

-- Captured: public.resolve_maintenance_report(p_report_id bigint)
CREATE OR REPLACE FUNCTION public.resolve_maintenance_report(p_report_id bigint)
 RETURNS boolean
 LANGUAGE sql
 SET search_path TO ''
AS $function$
                          SELECT fixmate_private.resolve_maintenance_report($1);
                          $function$;

-- Captured: public.assign_maintenance_report(p_report_id bigint, p_staff_id uuid)
CREATE OR REPLACE FUNCTION public.assign_maintenance_report(p_report_id bigint, p_staff_id uuid)
 RETURNS boolean
 LANGUAGE sql
 SET search_path TO ''
AS $function$
                      SELECT fixmate_private.assign_maintenance_report($1, $2);
                      $function$;

-- 3. Function privileges (from pg_proc proacl + schema ACL).
REVOKE ALL ON FUNCTION private.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fixmate_private.current_user_is_system_admin() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fixmate_private.current_user_is_system_admin() TO authenticated;
REVOKE ALL ON FUNCTION fixmate_private.claim_maintenance_report(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fixmate_private.claim_maintenance_report(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION fixmate_private.claim_maintenance_report(bigint) TO service_role;
REVOKE ALL ON FUNCTION fixmate_private.resolve_maintenance_report(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fixmate_private.resolve_maintenance_report(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION fixmate_private.resolve_maintenance_report(bigint) TO service_role;
REVOKE ALL ON FUNCTION fixmate_private.assign_maintenance_report(bigint, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fixmate_private.assign_maintenance_report(bigint, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION fixmate_private.assign_maintenance_report(bigint, uuid) TO service_role;
REVOKE ALL ON FUNCTION public.claim_maintenance_report(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_maintenance_report(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_maintenance_report(bigint) TO service_role;
REVOKE ALL ON FUNCTION public.resolve_maintenance_report(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_maintenance_report(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_maintenance_report(bigint) TO service_role;
REVOKE ALL ON FUNCTION public.assign_maintenance_report(bigint, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.assign_maintenance_report(bigint, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_maintenance_report(bigint, uuid) TO service_role;

-- 4. Table and column privileges based on current relation/column ACLs.
-- Revoke default broad grants in the fresh database before granting scoped
-- access, keeping privileged postgres/service_role internal access intact.
REVOKE ALL ON TABLE public.profiles FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.profiles TO service_role;
REVOKE ALL ON TABLE public.maintenance_categories FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.maintenance_categories TO service_role;
REVOKE ALL ON TABLE public.maintenance_reports FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.maintenance_reports TO service_role;
REVOKE ALL ON TABLE public.report_attachments FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.report_attachments TO service_role;
REVOKE ALL ON TABLE public.report_notes FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.report_notes TO service_role;
REVOKE ALL ON TABLE public.report_status_history FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.report_status_history TO service_role;
GRANT SELECT ON TABLE public.profiles,public.maintenance_categories,
  public.maintenance_reports,public.report_attachments,
  public.report_notes,public.report_status_history TO authenticated;
GRANT INSERT ON TABLE public.maintenance_reports,public.report_attachments,
  public.report_notes TO authenticated;
GRANT UPDATE (full_name, building, room_number) ON TABLE public.profiles TO authenticated;
-- Redundant effective column INSERT grants observed in current ACLs:
GRANT INSERT (resident_id, category_id, title, description, location)
 ON TABLE public.maintenance_reports TO authenticated;
GRANT INSERT (report_id, uploaded_by, storage_path)
 ON TABLE public.report_attachments TO authenticated;
GRANT INSERT (report_id, author_id, content)
 ON TABLE public.report_notes TO authenticated;

-- 5. RLS policies (13 public + 3 storage; original expressions preserved)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_status_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "View active categories" ON public.maintenance_categories AS PERMISSIVE FOR SELECT TO authenticated USING ((is_active = true));

CREATE POLICY "Residents create reports" ON public.maintenance_reports AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((resident_id = ( SELECT auth.uid() AS uid)) AND (status = 'new'::text) AND (assigned_to IS NULL) AND (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = ( SELECT auth.uid() AS uid)) AND (p.role = 'resident'::text))))));

CREATE POLICY "Residents view own reports" ON public.maintenance_reports AS PERMISSIVE FOR SELECT TO authenticated USING ((resident_id = ( SELECT auth.uid() AS uid)));

CREATE POLICY "Staff and admins view reports" ON public.maintenance_reports AS PERMISSIVE FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = ( SELECT auth.uid() AS uid)) AND (((p.role = 'maintenance_staff'::text) AND (((maintenance_reports.status = 'new'::text) AND (maintenance_reports.assigned_to IS NULL)) OR (maintenance_reports.assigned_to = ( SELECT auth.uid() AS uid)))) OR (p.role = ANY (ARRAY['moderator'::text, 'system_admin'::text])))))));

CREATE POLICY "FixMate admins can view all profiles" ON public.profiles AS PERMISSIVE FOR SELECT TO authenticated USING (( SELECT fixmate_private.current_user_is_system_admin() AS current_user_is_system_admin));

CREATE POLICY "Update own profile" ON public.profiles AS PERMISSIVE FOR UPDATE TO authenticated USING ((id = ( SELECT auth.uid() AS uid))) WITH CHECK ((id = ( SELECT auth.uid() AS uid)));

CREATE POLICY "View own profile" ON public.profiles AS PERMISSIVE FOR SELECT TO authenticated USING ((id = ( SELECT auth.uid() AS uid)));

CREATE POLICY "FixMate view report attachments" ON public.report_attachments AS PERMISSIVE FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM maintenance_reports r
  WHERE (r.id = report_attachments.report_id))));

CREATE POLICY "fixmate_resident_insert_attachments" ON public.report_attachments AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((uploaded_by = ( SELECT auth.uid() AS uid)) AND (array_length(storage.foldername(storage_path), 1) = 2) AND (split_part(storage_path, '/'::text, 1) = (( SELECT auth.uid() AS uid))::text) AND (split_part(storage_path, '/'::text, 2) = (report_id)::text) AND (EXISTS ( SELECT 1
   FROM (maintenance_reports r
     JOIN profiles p ON ((p.id = r.resident_id)))
  WHERE ((r.id = report_attachments.report_id) AND (r.resident_id = ( SELECT auth.uid() AS uid)) AND (p.role = 'resident'::text)))) AND (EXISTS ( SELECT 1
   FROM storage.objects o
  WHERE ((o.bucket_id = 'report-photos'::text) AND (o.name = report_attachments.storage_path))))));

CREATE POLICY "fixmate_resident_select_attachments" ON public.report_attachments AS PERMISSIVE FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM maintenance_reports r
  WHERE ((r.id = report_attachments.report_id) AND (r.resident_id = ( SELECT auth.uid() AS uid))))));

CREATE POLICY "Staff add internal notes" ON public.report_notes AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((author_id = ( SELECT auth.uid() AS uid)) AND (NULLIF(btrim(content), ''::text) IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM (profiles p
     JOIN maintenance_reports r ON ((r.id = report_notes.report_id)))
  WHERE ((p.id = ( SELECT auth.uid() AS uid)) AND ((p.role = ANY (ARRAY['moderator'::text, 'system_admin'::text])) OR ((p.role = 'maintenance_staff'::text) AND (r.assigned_to = ( SELECT auth.uid() AS uid)))))))));

CREATE POLICY "Staff read internal notes" ON public.report_notes AS PERMISSIVE FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM (profiles p
     JOIN maintenance_reports r ON ((r.id = report_notes.report_id)))
  WHERE ((p.id = ( SELECT auth.uid() AS uid)) AND ((p.role = ANY (ARRAY['moderator'::text, 'system_admin'::text])) OR ((p.role = 'maintenance_staff'::text) AND (r.assigned_to = ( SELECT auth.uid() AS uid))))))));

CREATE POLICY "View history of visible reports" ON public.report_status_history AS PERMISSIVE FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM maintenance_reports r
  WHERE (r.id = report_status_history.report_id))));

CREATE POLICY "fixmate_resident_read_photos" ON storage.objects AS PERMISSIVE FOR SELECT TO authenticated USING (((bucket_id = 'report-photos'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text) AND (EXISTS ( SELECT 1
   FROM maintenance_reports r
  WHERE (((r.id)::text = (storage.foldername(objects.name))[2]) AND (r.resident_id = ( SELECT auth.uid() AS uid)))))));

CREATE POLICY "fixmate_resident_upload_photos" ON storage.objects AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((bucket_id = 'report-photos'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text) AND (EXISTS ( SELECT 1
   FROM maintenance_reports r
  WHERE (((r.id)::text = (storage.foldername(objects.name))[2]) AND (r.resident_id = ( SELECT auth.uid() AS uid)))))));

CREATE POLICY "fixmate_staff_admin_read_photos" ON storage.objects AS PERMISSIVE FOR SELECT TO authenticated USING (((bucket_id = 'report-photos'::text) AND (array_length(storage.foldername(name), 1) = 2) AND (EXISTS ( SELECT 1
   FROM (maintenance_reports r
     JOIN profiles p ON ((p.id = ( SELECT auth.uid() AS uid))))
  WHERE (((r.id)::text = (storage.foldername(objects.name))[2]) AND ((r.resident_id)::text = (storage.foldername(objects.name))[1]) AND (((p.role = 'maintenance_staff'::text) AND (r.assigned_to = ( SELECT auth.uid() AS uid))) OR (p.role = ANY (ARRAY['moderator'::text, 'system_admin'::text]))))))));

-- 6. Existing private photo bucket (metadata only, not stored image bytes).
INSERT INTO storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
VALUES ('report-photos','report-photos',false,5242880,
        ARRAY['image/jpeg','image/png','image/webp']::text[]);

-- 7. Existing auth-to-profile creation trigger; ONLY on a fresh project.
-- No user-supplied role is read: private.handle_new_user sets resident.
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION private.handle_new_user();

COMMIT;

-- Category seed data is deliberately separate:
--   docs/sql/VERIFIED_CATEGORY_SEED_DRAFT.sql
-- No existing users or reports must be copied to a test database.
-- NOT included: proposed Moderator review and proposed FK index additions.
