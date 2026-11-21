import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate_mobile/data/models/maintenance_report.dart';
import 'package:fixmate_mobile/data/repositories/report_repository.dart';

void main() {
  test('Converts Supabase row using bigint ID and category name', () {
    final report = MaintenanceReport.fromDatabase({
      'id': 42,
      'title': 'Bathroom light',
      'description': 'Light stopped working',
      'location': 'Room 101',
      'status': 'new',
      'created_at': '2026-11-19T10:00:00+00:00',
    }, categoryName: 'Electrical');
    expect(report.id, '42');
    expect(report.category, 'Electrical');
    expect(report.status, MaintenanceStatus.newReport);
    expect(report.location, 'Room 101');
  });

  test('Maps in_progress and resolved from Supabase', () {
    expect(MaintenanceReport.parseDbStatus('in_progress'),
        MaintenanceStatus.inProgress);
    expect(MaintenanceReport.parseDbStatus('resolved'),
        MaintenanceStatus.resolved);
    expect(MaintenanceReport.parseDbStatus('unexpected'),
        MaintenanceStatus.unknown);
  });

  test('Offline repository still provides demo categories', () async {
    final repository = InMemoryReportRepository();
    final categories = await repository.getCategories();
    expect(categories, contains('Electrical'));
    expect((await repository.getMyReports()).length, 2);
  });
}
