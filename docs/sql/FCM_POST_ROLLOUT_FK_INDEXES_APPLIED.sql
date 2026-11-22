-- Applied already to populated hosted Supabase as
-- version 20261122171743, name fixmate_post_rollout_fk_indexes_live.
-- Archival SQL source for lecturer, NOT another migration to replay.
--
-- Four missing supporting indexes reported by the Performance Advisor.
-- All are non-unique BTREE indexes: no data, constraints, RLS or grants
-- change, and no billing upgrade is required.
BEGIN;
CREATE INDEX IF NOT EXISTS push_delivery_outbox_resident_id_idx
  ON public.push_delivery_outbox(resident_id);
CREATE INDEX IF NOT EXISTS report_notifications_report_id_idx
  ON public.report_notifications(report_id);
CREATE INDEX IF NOT EXISTS user_role_audit_actor_id_idx
  ON public.user_role_audit(actor_id);
CREATE INDEX IF NOT EXISTS user_role_audit_target_id_idx
  ON public.user_role_audit(target_id);
COMMIT;

-- Post-apply Supabase Performance Advisor:
-- unindexed_foreign_keys: 0 (cleared from previous 4).
-- Unused index informational notices can be expected while
-- newly-created tables contain few or no data rows.
-- Do not run blindly via supabase db push:
-- hosted applied versions intentionally differ from old local file names.
