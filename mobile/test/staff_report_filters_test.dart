import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate_mobile/data/models/staff_report.dart';
import 'package:fixmate_mobile/features/staff/staff_report_filters.dart';

void main() {
  final reports = [
    StaffReport(
      id: 11, residentId: 'r1', categoryId: 1,
      title: 'Sink leaking', description: 'Water on the kitchen floor',
      location: 'Room 204', status: 'new', assignedTo: null,
      createdAt: DateTime.utc(2026, 11, 21)),
    StaffReport(
      id: 12, residentId: 'r2', categoryId: 2,
      title: 'Heating repair', description: 'Radiator fixed',
      location: 'Room 314', status: 'resolved', assignedTo: 's1',
      createdAt: DateTime.utc(2026, 10, 10)),
  ];
  final now = DateTime.utc(2026, 11, 22);

  test('Search matches staff report title, description, location and id', () {
    for (final query in ['Sink', 'WATER', 'room 204', '11', 'category 1']) {
      expect(filterStaffVisibleReports(reports, query: query, now: now)
          .single.id, 11);
    }
    expect(filterStaffVisibleReports(reports,
        query: 'not-present', now: now), isEmpty);
  });

  test('Status and category filter combine', () {
    expect(filterStaffVisibleReports(reports, status: 'new',
        category: '1', now: now).map((r) => r.id), [11]);
    expect(filterStaffVisibleReports(reports, status: 'resolved',
        category: '1', now: now), isEmpty);
  });

  test('Recency filter retains only newer reports', () {
    expect(filterStaffVisibleReports(reports,
        dateRange: 'last7', now: now).map((r) => r.id), [11]);
    expect(filterStaffVisibleReports(reports,
        dateRange: 'all', now: now).length, 2);
  });

  test('Filtering does not broaden server-authorized rows', () {
    final onlyVisibleToStaff = [reports.last];
    expect(filterStaffVisibleReports(onlyVisibleToStaff,
        now: now).map((r) => r.id), [12]);
  });
}
