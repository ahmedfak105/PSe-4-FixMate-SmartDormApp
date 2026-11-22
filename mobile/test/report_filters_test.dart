import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate_mobile/features/operations/report_filters.dart';

void main() {
  final reports = <Map<String, dynamic>>[
    {
      'id': 1,
      'title': 'Leaking kitchen sink',
      'description': 'Water everywhere',
      'location': 'Dorm B, Room 210',
      'status': 'new',
      'assigned_to': null,
      'category_id': 4,
      'created_at': '2026-11-21T12:00:00Z',
    },
    {
      'id': 2,
      'title': 'Broken hallway light',
      'description': 'No electricity',
      'location': 'Dorm A',
      'status': 'resolved',
      'assigned_to': 'staff-1',
      'category_id': 5,
      'created_at': '2026-10-10T12:00:00Z',
    },
  ];
  const categories = {4: 'Plumbing', 5: 'Electrical'};
  final now = DateTime.utc(2026, 11, 22, 12);

  test('Free-text search checks title, description, location and category', () {
    for (final query in ['sink', 'WATER', 'room 210', 'plumbing', '1']) {
      expect(filterVisibleReports(reports,
          categoryNames: categories, text: query, now: now).single['id'], 1);
    }
    expect(filterVisibleReports(reports,
        categoryNames: categories, text: 'does-not-exist', now: now), isEmpty);
  });

  test('Status and category filters combine without altering source', () {
    final filtered = filterVisibleReports(reports, categoryNames: categories,
        status: 'resolved', category: '5', now: now);
    expect(filtered.map((r) => r['id']).toList(), [2]);
    expect(filterVisibleReports(reports, categoryNames: categories,
        status: 'new', category: '5', now: now), isEmpty);
    expect(reports.length, 2);
  });

  test('Date windows exclude old reports and preserve today', () {
    expect(filterVisibleReports(reports, categoryNames: categories,
        dateRange: 'last7', now: now).map((r) => r['id']), [1]);
    expect(filterVisibleReports(reports, categoryNames: categories,
        dateRange: 'last30', now: now).map((r) => r['id']), [1]);
    expect(filterVisibleReports(reports, categoryNames: categories,
        dateRange: 'all', now: now).length, 2);
  });

  test('Assignments include only unclaimed new reports', () {
    final filtered = filterVisibleReports(reports, categoryNames: categories,
        assignmentsOnly: true, now: now);
    expect(filtered.map((r) => r['id']), [1]);
  });

  test('Only visible server results are ever filtered', () {
    // This helper does not fetch or authorize rows. Supabase RLS is the real
    // boundary. A resident-visible response must never contain foreign rows.
    final alreadyVisible = [reports.first];
    final filtered = filterVisibleReports(alreadyVisible,
        categoryNames: categories, text: '', now: now);
    expect(filtered.map((r) => r['id']), [1]);
  });
}
