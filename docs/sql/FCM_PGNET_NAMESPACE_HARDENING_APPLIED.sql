-- Already applied to hosted Supabase project epsvagztisdovixlqehi.
-- This is an archive of the exact subsequent pg_net namespace hardening,
-- not a fresh migration to replay. Security Advisor after this migration
-- reports no extension_in_public warning.
--
-- Original pg_net extension registration namespace was public; it is
-- non-relocatable, so ALTER EXTENSION SET SCHEMA is unsupported.
-- A guarded RESTRICT drop/recreate in one transaction avoids CASCADE and
-- requires both pending requests and stored responses to be empty.
-- No report, profile, RLS or Storage data is affected.
BEGIN;
DO $guard$
BEGIN
  IF (SELECT count(*) FROM net.http_request_queue) <> 0
     OR (SELECT count(*) FROM net._http_response) <> 0 THEN
    RAISE EXCEPTION 'Cannot relocate pg_net while outstanding requests exist';
  END IF;
END
$guard$;
DROP EXTENSION pg_net;
CREATE EXTENSION pg_net WITH SCHEMA extensions;
COMMIT;
-- Post-check: pg_net extension namespace extensions; net.http_post still
-- works; Vault-gated trigger exists; retry cron remains active with
-- no externally queued HTTP requests and no private Vault secret installed.
