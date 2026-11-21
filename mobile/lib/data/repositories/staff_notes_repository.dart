import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/staff_note.dart';

/// The report_notes table is internal-only in FixMate: its existing policies
/// allow assigned maintenance staff, moderators and admins. This Flutter UI
/// intentionally exposes notes only to assigned maintenance staff.
class StaffNotesRepository {
  const StaffNotesRepository({required this.client, required this.staffId});

  final SupabaseClient client;
  final String staffId;

  void _assertSignedInStaff() {
    if (client.auth.currentUser?.id != staffId) {
      throw StateError('Your login session changed. Sign in again.');
    }
  }

  Future<List<StaffNote>> listForReport(int reportId) async {
    _assertSignedInStaff();
    final rows = await client
        .from('report_notes')
        .select('id, report_id, author_id, content, created_at')
        .eq('report_id', reportId)
        .order('created_at', ascending: true);
    return rows
        .map((row) => StaffNote.fromJson(row))
        .toList(growable: false);
  }

  Future<void> addNote({required int reportId, required String content}) async {
    _assertSignedInStaff();
    final checkedContent = validateInternalNote(content);
    await client.from('report_notes').insert({
      'report_id': reportId,
      'author_id': staffId,
      'content': checkedContent,
    });
  }
}
