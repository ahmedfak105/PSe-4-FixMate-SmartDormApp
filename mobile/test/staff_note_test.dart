import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate_mobile/data/models/staff_note.dart';

void main() {
  test('Staff note maps from Supabase report_notes row', () {
    final note = StaffNote.fromJson({
      'id': 17,
      'report_id': 9,
      'author_id': 'staff-uuid',
      'content': 'Replaced broken bathroom light.',
      'created_at': '2026-11-21T00:00:00+00:00',
    });
    expect(note.id, 17);
    expect(note.reportId, 9);
    expect(note.content, 'Replaced broken bathroom light.');
  });

  test('Empty internal notes are rejected', () {
    expect(() => validateInternalNote(' \n  '), throwsFormatException);
  });

  test('Leading and trailing whitespace is removed', () {
    expect(validateInternalNote('  Replaced the light.  '), 'Replaced the light.');
  });

  test('Oversized notes are rejected', () {
    expect(() => validateInternalNote(List.filled(3001, 'x').join()), throwsFormatException);
  });
}
