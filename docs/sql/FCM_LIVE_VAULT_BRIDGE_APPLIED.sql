-- FixMate F05.2 — exact 2026-11-22 hosted Vault-gated dispatch bridge.
--
-- ALREADY APPLIED to project epsvagztisdovixlqehi as the hosted migration
-- version 20261122170759, name fixmate_push_vault_bridge_live.
-- This file is an archival source copy, NOT a migration to replay.
-- In particular, do NOT run a new supabase db push over the populated DB:
-- original source migration timestamps and remote versions differ.
--
-- This never embeds any Firebase JSON, access keys or webhook values.
-- Until a private matching secret is entered into BOTH:
--  (A) Supabase Edge Function Secret FIXMATE_PUSH_WEBHOOK_SECRET and
--  (B) Supabase Database Vault secret fixmate_push_webhook_secret
-- the dispatcher returns NULL, and cron generates NO outgoing HTTP calls.
-- The Edge sender additionally needs FIREBASE_SERVICE_ACCOUNT_JSON.
-- It is a no-spend Free-plan DB integration with no paid resource provisioned.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;

CREATE OR REPLACE FUNCTION fixmate_private.dispatch_push_outbox_vault()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_secret text;
  v_request_id bigint;
BEGIN
  SELECT ds.decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets ds
  WHERE ds.name = 'fixmate_push_webhook_secret';

  IF v_secret IS NULL OR length(v_secret) < 32 THEN
    RETURN NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.push_delivery_outbox q
    WHERE q.attempts < 5
      AND (
        (q.state = 'pending' AND q.next_attempt_at <= now())
        OR
        (q.state = 'processing' AND
          q.claimed_at < now() - interval '10 minutes')
      )
  ) THEN
    RETURN NULL;
  END IF;

  SELECT net.http_post(
    url := 'https://epsvagztisdovixlqehi.supabase.co/functions/v1/send-report-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-fixmate-push-secret', v_secret
    ),
    body := jsonb_build_object('source', 'fixmate-outbox'),
    timeout_milliseconds := 5000
  ) INTO v_request_id;
  RETURN v_request_id;
END;
$fn$;

REVOKE ALL ON FUNCTION fixmate_private.dispatch_push_outbox_vault()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fixmate_private.dispatch_push_outbox_vault()
  FROM service_role;

CREATE OR REPLACE FUNCTION fixmate_private.kick_push_outbox()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
BEGIN
  BEGIN
    PERFORM fixmate_private.dispatch_push_outbox_vault();
  EXCEPTION WHEN OTHERS THEN
    NULL;  -- Best effort: never break report status changes.
  END;
  RETURN NULL;
END;
$fn$;

REVOKE ALL ON FUNCTION fixmate_private.kick_push_outbox()
  FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS fixmate_push_send_on_queue_insert
  ON public.push_delivery_outbox;
CREATE TRIGGER fixmate_push_send_on_queue_insert
  AFTER INSERT ON public.push_delivery_outbox
  FOR EACH STATEMENT
  EXECUTE FUNCTION fixmate_private.kick_push_outbox();

SELECT cron.schedule(
  'fixmate_push_vault_dispatch',
  '*/5 * * * *',
  'SELECT fixmate_private.dispatch_push_outbox_vault();'
);
COMMIT;

-- Verification performed on actual hosted DB after execution:
--   pg_net = true; pg_cron = true;
--   cron.job: fixmate_push_vault_dispatch active, schedule */5 * * * *;
--   Vault secret count 0; net.http_request_queue count 0;
--   private function not executable by anon/authenticated;
--   no registered device tokens.
-- Rollback-only smoke simulated an Android token, report status transition
-- and outbox row; observed one newly queued job and no HTTP calls (unarmed).
-- ROLLBACK left 7 pre-existing reports, zero QA devices/jobs/notifications.
--
-- To STOP retry polling on a genuine incident (operator only):
--   SELECT cron.unschedule('fixmate_push_vault_dispatch');
-- Stop here rather than deleting app data or resetting Supabase.
