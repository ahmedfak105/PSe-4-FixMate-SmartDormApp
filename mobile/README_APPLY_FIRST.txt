FixMate - Maintenance Staff INTERNAL Notes patch

What this changes:
- Staff Dashboard -> My Jobs -> Internal notes for reports assigned to the signed-in maintenance staff member (including resolved report #9).
- Read existing internal notes from public.report_notes.
- Save a non-empty internal note using the logged-in staff user as author_id.
- Notes remain INTERNAL. Residents cannot read report_notes with the existing SELECT RLS policy.
- No SQL schema modifications, no service-role key.

Required SQL in Supabase SQL Editor (run ONCE before trying Add note):

    ALTER TABLE public.report_notes ENABLE ROW LEVEL SECURITY;
    GRANT INSERT ON TABLE public.report_notes TO authenticated;

The existing RLS policies 'Staff add internal notes' and 'Staff read internal notes' are kept unchanged. SELECT grant already exists according to the user's inspection.

How to install:
1. Stop flutter run ('q') and back up the current FixMate_Flutter_Starter folder.
2. Merge 'lib/' and 'test/' from this patch into your current project; overwrite matching files. Do not delete other files.
3. Run flutter pub get, flutter test, flutter analyze.
4. Start with your original SUPABASE_URL/SUPABASE_PUBLISHABLE_KEY dart-defines.
5. Sign in as Maintenance Staff; open 'My jobs'; select Internal notes for report #9; add a note.
6. Verify in Supabase: SELECT id, report_id, author_id, content, created_at FROM public.report_notes WHERE report_id = 9 ORDER BY created_at DESC;

The patch has not been run with the user's local Flutter SDK. RLS/grants may cause runtime errors until SQL is applied. Leave internal notes private; do not add Resident SELECT policy unless product design intentionally introduces a separate public note type.
