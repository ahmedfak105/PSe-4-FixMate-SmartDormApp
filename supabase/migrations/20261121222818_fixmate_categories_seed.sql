-- FixMate category seed snapshot from Supabase on 2026-11-22.
-- EIGHT category names only; no user or report data.
-- Run in a clean local/staging DB after the baseline migration only.
-- Do not apply to the existing live project.
INSERT INTO public.maintenance_categories (name, is_active)
VALUES
  ('Plumbing', true),
  ('Electrical', true),
  ('Heating', true),
  ('Doors & Windows', true),
  ('Furniture', true),
  ('Internet & Wi-Fi', true),
  ('Cleaning', true),
  ('Other', true)
ON CONFLICT (name) DO NOTHING;

-- Verify with:
-- SELECT id,name,is_active FROM public.maintenance_categories ORDER BY id;
