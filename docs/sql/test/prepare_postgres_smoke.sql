-- Isolated PostgreSQL smoke harness ONLY.
-- Stubs enough Supabase-managed schemas to parse and exercise FixMate SQL.
-- NOT a substitute for a real Supabase stack or complete API/Storage tests.
-- Run only against a disposable Postgres 17 database.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;

CREATE SCHEMA auth;
CREATE SCHEMA storage;

CREATE TABLE auth.users (
  id uuid PRIMARY KEY,
  raw_user_meta_data jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE FUNCTION auth.uid()
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

-- Supabase Storage's foldername returns folder components, excluding the file.
CREATE FUNCTION storage.foldername(object_name text)
RETURNS text[] LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN position('/' in object_name) = 0
    THEN ARRAY[]::text[]
    ELSE (string_to_array(object_name, '/'))[
      1:(array_length(string_to_array(object_name, '/'), 1) - 1)
    ] END;
$$;

CREATE TABLE storage.buckets (
  id text PRIMARY KEY,
  name text NOT NULL,
  public boolean NOT NULL DEFAULT false,
  file_size_limit bigint,
  allowed_mime_types text[]
);
CREATE TABLE storage.objects (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  bucket_id text NOT NULL REFERENCES storage.buckets(id),
  name text NOT NULL
);
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

GRANT USAGE ON SCHEMA auth,storage TO authenticated,anon;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated,anon;
GRANT EXECUTE ON FUNCTION storage.foldername(text) TO authenticated,anon;
GRANT SELECT ON TABLE storage.objects TO authenticated;
